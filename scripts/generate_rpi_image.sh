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

# Determine base image and build strategy
if [ -n "$IMAGE_LINK" ]; then
    echo "Using custom base image: $IMAGE_LINK"
    # Download the custom image
    BASE_IMAGE_FILE="$OUTPUT_DIR/base-image.img"
    echo "Downloading $IMAGE_LINK..."
    wget -O "$BASE_IMAGE_FILE" "$IMAGE_LINK" || curl -L -o "$BASE_IMAGE_FILE" "$IMAGE_LINK"
    
    # Decompress if needed
    if [[ "$BASE_IMAGE_FILE" == *.xz ]]; then
        echo "Decompressing xz image..."
        xz -d "$BASE_IMAGE_FILE"
        BASE_IMAGE_FILE="${BASE_IMAGE_FILE%.xz}"
    elif [[ "$BASE_IMAGE_FILE" == *.gz ]]; then
        echo "Decompressing gzip image..."
        gunzip "$BASE_IMAGE_FILE"
        BASE_IMAGE_FILE="${BASE_IMAGE_FILE%.gz}"
    fi
    
    IMAGE_FILE="$BASE_IMAGE_FILE"
else
    # Use rpi-image-gen to create base image
    echo "Using rpi-image-gen to create base image for suite: $SUITE"
    
    # Map suite to rpi-image-gen layer
    case "$SUITE" in
        bookworm|bullseye)
            BASE_LAYER="bookworm-minbase"
            ;;
        trixie)
            BASE_LAYER="trixie-minbase"
            ;;
        jammy|focal|buster)
            # For Ubuntu/older Debian, we'll use bookworm as base and customize
            BASE_LAYER="bookworm-minbase"
            echo "NOTE: Using bookworm base for $SUITE (will customize after)"
            ;;
        *)
            echo "ERROR: Unsupported SUITE '$SUITE' for rpi-image-gen" >&2
            exit 1
            ;;
    esac
    
    # Create temporary config for rpi-image-gen
    # Use absolute path for config file
    mkdir -p "$OUTPUT_DIR"
    CONFIG_FILE="$(cd "$OUTPUT_DIR" && pwd)/rpi-image-gen-config.yaml"
    cat > "$CONFIG_FILE" << EOF
device:
  layer: rpi-cm4  # uConsole uses CM4 (Compute Module 4)

image:
  layer: image-rpios
  boot_part_size: 512M
  root_part_size: ${ROOTFS_SIZE}M
  name: ${IMAGE_NAME}

layer:
  base: ${BASE_LAYER}
EOF
    
    echo "Generated rpi-image-gen config:"
    cat "$CONFIG_FILE"
    echo ""
    
    # Run rpi-image-gen to build base image
    echo "Building base image with rpi-image-gen..."
    cd "$RPI_IMAGE_GEN"
    
    # Check for podman (required for rootless mode)
    if ! command -v podman &> /dev/null; then
        echo "ERROR: podman is required for rootless image building" >&2
        echo "Install with: sudo apt-get install -y podman" >&2
        exit 1
    fi
    
    # Install dependencies if needed
    if [ ! -f "/usr/bin/mmdebstrap" ] || [ ! -f "/usr/bin/genimage" ]; then
        echo "Installing rpi-image-gen dependencies..."
        ./install_deps.sh || echo "WARNING: Failed to install dependencies, continuing anyway"
    fi
    
    # Build the image
    # Use absolute path for build directory
    mkdir -p "$OUTPUT_DIR"
    BUILD_DIR="$(cd "$OUTPUT_DIR" && pwd)/rpi-image-gen-build"
    mkdir -p "$BUILD_DIR"
    
    # Run rpi-image-gen with podman unshare for rootless mode
    # This fixes the "please use unshare with rootless" error
    echo "Running: podman unshare ./rpi-image-gen build -c $CONFIG_FILE -B $BUILD_DIR"
    podman unshare ./rpi-image-gen build -c "$CONFIG_FILE" -B "$BUILD_DIR" || {
        echo "WARNING: rpi-image-gen build failed"
        echo "NOTE: For manual rootfs creation and kernel installation, you'll need root privileges"
        echo "Falling back to manual rootfs creation (requires sudo)..."
        
        # Check if we have root for fallback
        if [ "$EUID" -ne 0 ]; then
            echo "ERROR: Fallback requires root privileges. Please run with sudo or fix rpi-image-gen errors." >&2
            exit 1
        fi
        
        # Fallback: Create rootfs manually using debootstrap
        echo "Creating base rootfs with debootstrap..."
        ROOTFS_DIR="$OUTPUT_DIR/rootfs-${SUITE}-${ARCH}"
        
        # Use existing build-image.sh if available
        if [ -x "$SCRIPT_DIR/build-image.sh" ]; then
            SUITE="$SUITE" ARCH="$ARCH" "$SCRIPT_DIR/build-image.sh" "$OUTPUT_DIR"
        else
            # Manual debootstrap
            mkdir -p "$ROOTFS_DIR"
            if [[ "$SUITE" == "jammy" ]] || [[ "$SUITE" == "focal" ]]; then
                REPO_URL="http://ports.ubuntu.com/ubuntu-ports"
            else
                REPO_URL="http://deb.debian.org/debian"
            fi
            
            debootstrap --arch="$ARCH" "$SUITE" "$ROOTFS_DIR" "$REPO_URL"
        fi
        
        # We'll create the image manually below
        IMAGE_FILE="$OUTPUT_DIR/${IMAGE_NAME}.img"
        MANUAL_IMAGE=true
    }
    
    # Find the generated image
    if [ -z "${MANUAL_IMAGE:-}" ]; then
        IMAGE_FILE=$(find "$BUILD_DIR" -name "*.img" -type f | head -1)
        
        if [ -z "$IMAGE_FILE" ]; then
            echo "ERROR: rpi-image-gen did not produce an image file" >&2
            exit 1
        fi
        
        echo "Base image created: $IMAGE_FILE"
    fi
    
    cd "$REPO_ROOT"
fi

# Check if we need to customize the image (only if using manual fallback or custom kernel)
if [ -n "${MANUAL_IMAGE:-}" ] || [ "$KERNEL_MODE" != "none" ]; then
    echo ""
    echo "================================================"
    echo "Customizing image for uConsole..."
    echo "================================================"
    
    # These operations require root privileges
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: Image customization requires root privileges" >&2
        echo "Please run with sudo for kernel installation and image customization" >&2
        exit 1
    fi

    # Setup loop device for the image
    setup_loop_device "$IMAGE_FILE"

# Mount partitions
TEMP_MOUNT="$OUTPUT_DIR/temp_mount"
mount_partitions "$LOOP_DEVICE" "$TEMP_MOUNT" 1 2

# Bind mount system directories for chroot
bind_mount_system "$TEMP_MOUNT"

# Setup QEMU for cross-architecture chroot
setup_qemu_chroot "$TEMP_MOUNT" "aarch64"

# Install kernel based on mode
case "$KERNEL_MODE" in
    prebuilt)
        echo "Installing prebuilt ClockworkPi kernel..."
        "$SCRIPT_DIR/install_clockworkpi_kernel.sh" "$TEMP_MOUNT" "$SUITE"
        ;;
    build)
        echo "Building ClockworkPi kernel from source..."
        KERNEL_DEBS="$REPO_ROOT/artifacts/kernel-debs"
        "$SCRIPT_DIR/build_clockworkpi_kernel.sh" "$KERNEL_DEBS"
        
        # Copy debs to mounted image and install
        mkdir -p "$TEMP_MOUNT/tmp/kernel-debs"
        cp "$KERNEL_DEBS"/*.deb "$TEMP_MOUNT/tmp/kernel-debs/"
        
        echo "Installing kernel packages in chroot..."
        chroot "$TEMP_MOUNT" /bin/bash -c "
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

# Apply any additional customizations if setup-suite.sh exists
if [ -x "$SCRIPT_DIR/setup-suite.sh" ]; then
    echo "Applying suite-specific customizations..."
    # Note: setup-suite.sh expects a rootfs directory, so we pass our mount point
    # We need to make sure it doesn't try to mount again since we already mounted
    SUITE="$SUITE" RECOMPILE_KERNEL="false" "$SCRIPT_DIR/setup-suite.sh" "$OUTPUT_DIR" || {
        echo "WARNING: setup-suite.sh failed or not applicable"
    }
fi

# Sync and cleanup
    sync
    cleanup_mounts
fi

# Compress image if requested
FINAL_IMAGE="$OUTPUT_DIR/${IMAGE_NAME}.img"
if [ "$IMAGE_FILE" != "$FINAL_IMAGE" ]; then
    mv "$IMAGE_FILE" "$FINAL_IMAGE"
fi

if [ "$COMPRESS_FORMAT" = "xz" ]; then
    echo "Compressing image with xz..."
    xz -9 -T 0 "$FINAL_IMAGE"
    FINAL_IMAGE="${FINAL_IMAGE}.xz"
elif [ "$COMPRESS_FORMAT" = "gzip" ]; then
    echo "Compressing image with gzip..."
    gzip -9 "$FINAL_IMAGE"
    FINAL_IMAGE="${FINAL_IMAGE}.gz"
fi

echo ""
echo "================================================"
echo "Image creation complete!"
echo "================================================"
echo "Image file: $FINAL_IMAGE"
ls -lh "$FINAL_IMAGE"
echo ""
echo "To write to SD card:"
if [[ "$FINAL_IMAGE" == *.xz ]]; then
    echo "  xz -dc $FINAL_IMAGE | sudo dd of=/dev/sdX bs=4M status=progress"
elif [[ "$FINAL_IMAGE" == *.gz ]]; then
    echo "  gunzip -c $FINAL_IMAGE | sudo dd of=/dev/sdX bs=4M status=progress"
else
    echo "  sudo dd if=$FINAL_IMAGE of=/dev/sdX bs=4M status=progress"
fi
echo "  (Replace /dev/sdX with your SD card device)"

exit 0
