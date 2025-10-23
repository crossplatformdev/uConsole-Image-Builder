#!/bin/bash
#
# generate_rpi_image.sh - Wrapper script for rpi-image-gen with ClockworkPi kernel integration
#
# This script wraps rpi-image-gen to create Raspberry Pi images for uConsole devices,
# with integrated ClockworkPi kernel installation.
#
# Usage: generate_rpi_image.sh
#
# Environment Variables:
#   IMAGE_NAME       - Name for the generated image (default: uconsole-<suite>-<arch>)
#   IMAGE_LINK       - Custom image link/URL to use as base
#   SUITE            - Distribution suite (jammy|bookworm|bullseye|buster|focal|trixie|all)
#   ARCH             - Architecture (default: arm64)
#   ROOTFS_SIZE      - Root filesystem size in MB (default: 4096)
#   OUTPUT_DIR       - Output directory for images (default: output/images)
#   KERNEL_MODE      - Kernel installation mode: prebuilt|build|none (default: prebuilt)
#   COMPRESS_FORMAT  - Compression format: xz|gzip|none (default: xz)
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common mount functions
source "$SCRIPT_DIR/common_mounts.sh"

# Configuration from environment
SUITE="${SUITE:-jammy}"
ARCH="${ARCH:-arm64}"
ROOTFS_SIZE="${ROOTFS_SIZE:-4096}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/output/images}"
IMAGE_NAME="${IMAGE_NAME:-}"
IMAGE_LINK="${IMAGE_LINK:-}"
KERNEL_MODE="${KERNEL_MODE:-prebuilt}"
COMPRESS_FORMAT="${COMPRESS_FORMAT:-xz}"

# Supported suites
ALL_SUITES=("buster" "bullseye" "bookworm" "trixie" "focal" "jammy")

echo "================================================"
echo "uConsole Image Generator (rpi-image-gen wrapper)"
echo "================================================"

# Handle "all" suite option
if [ "$SUITE" = "all" ]; then
    echo "Building images for all supported suites..."
    for suite in "${ALL_SUITES[@]}"; do
        echo ""
        echo "================================================"
        echo "Building suite: $suite"
        echo "================================================"
        SUITE="$suite" "$0"
    done
    exit 0
fi

# Validate suite
VALID_SUITE=false
for valid in "${ALL_SUITES[@]}"; do
    if [ "$SUITE" = "$valid" ]; then
        VALID_SUITE=true
        break
    fi
done

if [ "$VALID_SUITE" != "true" ]; then
    echo "ERROR: Invalid SUITE '$SUITE'" >&2
    echo "Valid suites: ${ALL_SUITES[*]}, all" >&2
    exit 1
fi

# Set default image name if not provided
if [ -z "$IMAGE_NAME" ]; then
    IMAGE_NAME="uconsole-${SUITE}-${ARCH}"
fi

echo "Suite: $SUITE"
echo "Architecture: $ARCH"
echo "Image Name: $IMAGE_NAME"
echo "Root FS Size: ${ROOTFS_SIZE}MB"
echo "Output Directory: $OUTPUT_DIR"
echo "Kernel Mode: $KERNEL_MODE"
echo "Compress Format: $COMPRESS_FORMAT"
[ -n "$IMAGE_LINK" ] && echo "Base Image Link: $IMAGE_LINK"
echo "================================================"

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)" >&2
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Setup cleanup trap
trap_cleanup

# Check if rpi-image-gen is available
RPI_IMAGE_GEN="$REPO_ROOT/rpi-image-gen"
if [ ! -d "$RPI_IMAGE_GEN" ]; then
    echo "ERROR: rpi-image-gen not found at $RPI_IMAGE_GEN" >&2
    echo "Initialize the submodule: git submodule update --init --recursive" >&2
    exit 1
fi

# Determine base image
if [ -n "$IMAGE_LINK" ]; then
    echo "Using custom base image: $IMAGE_LINK"
    BASE_IMAGE_URL="$IMAGE_LINK"
else
    # Use standard Raspberry Pi OS images
    # TODO: Map suite to appropriate Raspberry Pi OS image
    echo "Using standard Raspberry Pi OS base for suite: $SUITE"
    
    # For now, we'll use debootstrap-based approach instead of rpi-image-gen
    # since rpi-image-gen is designed for Raspberry Pi OS specifically
    echo "NOTE: Falling back to debootstrap-based image creation"
    
    # Use existing build-image.sh and setup-suite.sh approach
    ROOTFS_DIR="$OUTPUT_DIR/rootfs-${SUITE}-${ARCH}"
    
    echo "Creating base rootfs with debootstrap..."
    SUITE="$SUITE" ARCH="$ARCH" "$SCRIPT_DIR/build-image.sh" "$OUTPUT_DIR"
    
    # Install kernel based on mode
    case "$KERNEL_MODE" in
        prebuilt)
            echo "Installing prebuilt ClockworkPi kernel..."
            "$SCRIPT_DIR/install_clockworkpi_kernel.sh" "$ROOTFS_DIR" "$SUITE"
            ;;
        build)
            echo "Building ClockworkPi kernel from source..."
            KERNEL_DEBS="$REPO_ROOT/artifacts/kernel-debs"
            "$SCRIPT_DIR/build_clockworkpi_kernel.sh" "$KERNEL_DEBS"
            
            # Copy debs to rootfs and install
            mkdir -p "$ROOTFS_DIR/tmp/kernel-debs"
            cp "$KERNEL_DEBS"/*.deb "$ROOTFS_DIR/tmp/kernel-debs/"
            
            echo "Installing kernel packages in chroot..."
            chroot "$ROOTFS_DIR" /bin/bash -c "
                apt-get update
                apt-get install -y initramfs-tools
                dpkg -i /tmp/kernel-debs/*.deb || apt-get install -f -y
                rm -rf /tmp/kernel-debs
            "
            ;;
        none)
            echo "Skipping kernel installation (KERNEL_MODE=none)"
            ;;
        *)
            echo "ERROR: Invalid KERNEL_MODE '$KERNEL_MODE'" >&2
            echo "Valid modes: prebuilt, build, none" >&2
            exit 1
            ;;
    esac
    
    # Apply suite-specific customizations
    echo "Applying suite customizations..."
    SUITE="$SUITE" RECOMPILE_KERNEL="false" "$SCRIPT_DIR/setup-suite.sh" "$OUTPUT_DIR"
    
    # Create disk image from rootfs
    echo "Creating disk image from rootfs..."
    IMAGE_FILE="$OUTPUT_DIR/${IMAGE_NAME}.img"
    
    # Calculate image size (rootfs size + boot partition + margin)
    IMAGE_SIZE=$((ROOTFS_SIZE + 256 + 256))  # Add 256MB for boot + 256MB margin
    
    # Create empty image file
    dd if=/dev/zero of="$IMAGE_FILE" bs=1M count="$IMAGE_SIZE" status=progress
    
    # Create partition table
    echo "Creating partition table..."
    parted "$IMAGE_FILE" --script mklabel msdos
    parted "$IMAGE_FILE" --script mkpart primary fat32 1MiB 257MiB
    parted "$IMAGE_FILE" --script mkpart primary ext4 257MiB 100%
    parted "$IMAGE_FILE" --script set 1 boot on
    
    # Setup loop device
    setup_loop_device "$IMAGE_FILE"
    
    # Format partitions
    echo "Formatting partitions..."
    mkfs.vfat -F 32 -n BOOT "${LOOP_DEVICE}p1"
    mkfs.ext4 -L rootfs "${LOOP_DEVICE}p2"
    
    # Mount partitions
    TEMP_MOUNT="$OUTPUT_DIR/temp_mount"
    mount_partitions "$LOOP_DEVICE" "$TEMP_MOUNT" 1 2
    
    # Copy rootfs content
    echo "Copying rootfs content to image..."
    rsync -aHAX --info=progress2 "$ROOTFS_DIR/" "$TEMP_MOUNT/"
    
    # Ensure fstab is configured
    echo "Configuring fstab..."
    cat > "$TEMP_MOUNT/etc/fstab" << 'EOF'
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1
/dev/mmcblk0p1  /boot/firmware  vfat    defaults          0       2
EOF
    
    # Sync filesystems
    sync
    
    # Cleanup mounts
    cleanup_mounts
    
    # Compress image if requested
    if [ "$COMPRESS_FORMAT" = "xz" ]; then
        echo "Compressing image with xz..."
        xz -9 -T 0 "$IMAGE_FILE"
        IMAGE_FILE="${IMAGE_FILE}.xz"
    elif [ "$COMPRESS_FORMAT" = "gzip" ]; then
        echo "Compressing image with gzip..."
        gzip -9 "$IMAGE_FILE"
        IMAGE_FILE="${IMAGE_FILE}.gz"
    fi
    
    echo "================================================"
    echo "Image creation complete!"
    echo "================================================"
    echo "Image file: $IMAGE_FILE"
    ls -lh "$IMAGE_FILE"
    echo ""
    echo "To write to SD card:"
    echo "  xz -dc $IMAGE_FILE | sudo dd of=/dev/sdX bs=4M status=progress"
    echo "  (Replace /dev/sdX with your SD card device)"
fi

exit 0
