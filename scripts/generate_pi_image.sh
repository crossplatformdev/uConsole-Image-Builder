#!/bin/bash
#
# generate_pi_image.sh - Wrapper script for pi-gen (ClockworkPi-pi-gen) with ClockworkPi kernel integration
#
# This script wraps pi-gen to create Raspberry Pi images for uConsole devices,
# with integrated ClockworkPi kernel installation.
#
# Usage: generate_pi_image.sh
#
# Environment Variables:
#   IMAGE_NAME       - Name for the generated image (default: uconsole-<suite>-<arch>)
#   SUITE            - Distribution suite (bookworm|trixie|all)
#   ARCH             - Architecture (default: arm64)
#   OUTPUT_DIR       - Output directory for images (default: output/images)
#   KERNEL_MODE      - Kernel installation mode: prebuilt|build|none (default: prebuilt)
#   COMPRESS_FORMAT  - Compression format: xz|gz|zip|none (default: xz)
#   UCONSOLE_CORE    - Core model: cm4|cm5 (default: cm4)
#   DESKTOP          - Desktop environment: gnome|kde|mate|xfce|lxde|lxqt|cinnamon|gnome-flashback|none (default: none for lite)
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration from environment
SUITE="${SUITE:-trixie}"
ARCH="${ARCH:-arm64}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/output/images}"
IMAGE_NAME="${IMAGE_NAME:-}"
KERNEL_MODE="${KERNEL_MODE:-prebuilt}"
COMPRESS_FORMAT="${COMPRESS_FORMAT:-xz}"
UCONSOLE_CORE="${UCONSOLE_CORE:-cm4}"
DESKTOP="${DESKTOP:-none}"

# Supported suites
ALL_SUITES=("bookworm" "trixie")

echo "================================================"
echo "uConsole Image Generator (pi-gen wrapper)"
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
    if [ "$DESKTOP" = "none" ]; then
        IMAGE_NAME="uconsole-${SUITE}-${UCONSOLE_CORE}"
    else
        IMAGE_NAME="uconsole-${SUITE}-${UCONSOLE_CORE}-${DESKTOP}"
    fi
fi

echo "Suite: $SUITE"
echo "Architecture: $ARCH"
echo "Image Name: $IMAGE_NAME"
echo "Output Directory: $OUTPUT_DIR"
echo "Kernel Mode: $KERNEL_MODE"
echo "Compress Format: $COMPRESS_FORMAT"
echo "uConsole Core: $UCONSOLE_CORE"
echo "Desktop: $DESKTOP"
echo "================================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if pi-gen is available
PI_GEN_DIR="$REPO_ROOT/pi-gen"
if [ ! -d "$PI_GEN_DIR" ]; then
    echo "ERROR: pi-gen not found at $PI_GEN_DIR" >&2
    echo "Initialize the submodule: git submodule update --init --recursive" >&2
    exit 1
fi

# Install dependencies if needed
echo "Checking pi-gen dependencies..."
if ! command -v debootstrap &> /dev/null; then
    echo "Installing pi-gen dependencies..."
    sudo apt-get update
    sudo apt-get install -y coreutils quilt parted qemu-user-static debootstrap zerofree zip \
        dosfstools e2fsprogs libarchive-tools libcap2-bin grep rsync xz-utils file git curl bc \
        gpg pigz xxd arch-test bmap-tools kmod
fi

# Prepare pi-gen config
cd "$PI_GEN_DIR"

# Create config file
CONFIG_FILE="$PI_GEN_DIR/config"
cat > "$CONFIG_FILE" << EOF
# uConsole Image Configuration
IMG_NAME="${IMAGE_NAME}"
RELEASE="${SUITE}"
TARGET_HOSTNAME="uconsole"
FIRST_USER_NAME="clockworkpi"
FIRST_USER_PASS="clockworkpi"
DISABLE_FIRST_BOOT_USER_RENAME=1
ENABLE_SSH=1
WPA_COUNTRY="US"
LOCALE_DEFAULT="en_US.UTF-8"
TIMEZONE_DEFAULT="UTC"
KEYBOARD_KEYMAP="us"
KEYBOARD_LAYOUT="English (US)"
EOF

# Set compression based on format
case "$COMPRESS_FORMAT" in
    xz)
        echo 'DEPLOY_COMPRESSION="xz"' >> "$CONFIG_FILE"
        echo 'COMPRESSION_LEVEL=6' >> "$CONFIG_FILE"
        ;;
    gz)
        echo 'DEPLOY_COMPRESSION="gz"' >> "$CONFIG_FILE"
        echo 'COMPRESSION_LEVEL=6' >> "$CONFIG_FILE"
        ;;
    zip)
        echo 'DEPLOY_COMPRESSION="zip"' >> "$CONFIG_FILE"
        echo 'COMPRESSION_LEVEL=6' >> "$CONFIG_FILE"
        ;;
    none)
        echo 'DEPLOY_COMPRESSION="none"' >> "$CONFIG_FILE"
        ;;
    *)
        echo "ERROR: Invalid COMPRESS_FORMAT '$COMPRESS_FORMAT'" >&2
        echo "Valid formats: xz, gz, zip, none" >&2
        exit 1
        ;;
esac

# Set stage list based on desktop
if [ "$DESKTOP" = "none" ]; then
    # Lite build (stage0, stage1, stage2)
    echo 'STAGE_LIST="stage0 stage1 stage2"' >> "$CONFIG_FILE"
else
    # Full desktop build (stage0, stage1, stage2, stage3, stage4)
    echo 'STAGE_LIST="stage0 stage1 stage2 stage3 stage4"' >> "$CONFIG_FILE"
fi

echo ""
echo "Generated pi-gen config:"
cat "$CONFIG_FILE"
echo ""

# Create a custom stage for kernel installation if needed
if [ "$KERNEL_MODE" != "none" ]; then
    echo "Setting up custom kernel installation stage..."
    CUSTOM_STAGE="$PI_GEN_DIR/stage2/06-uconsole-kernel"
    mkdir -p "$CUSTOM_STAGE"
    
    case "$KERNEL_MODE" in
        prebuilt)
            # Create script to install prebuilt kernel
            cat > "$CUSTOM_STAGE/00-run-chroot.sh" << 'KERNELEOF'
#!/bin/bash -e

# Install ClockworkPi kernel from repository
echo "Installing ClockworkPi kernel from repository..."

# Add ClockworkPi repository
cat > /etc/apt/sources.list.d/clockworkpi.list << EOF
deb https://raw.githubusercontent.com/clockworkpi/apt/main/ stable main
EOF

# Add repository key
wget -qO - https://raw.githubusercontent.com/clockworkpi/apt/main/KEY.gpg | apt-key add - || true

# Update and install kernel
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    uconsole-kernel-cm4-rpi \
    clockworkpi-audio \
    clockworkpi-cm-firmware || true

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "ClockworkPi kernel installed successfully"
KERNELEOF
            chmod +x "$CUSTOM_STAGE/00-run-chroot.sh"
            ;;
        build)
            # Create script to install kernel from debs
            cat > "$CUSTOM_STAGE/00-run.sh" << 'BUILDEOF'
#!/bin/bash -e

# Check if kernel debs exist
KERNEL_DEBS="${REPO_ROOT}/artifacts/kernel-debs"
if [ ! -d "$KERNEL_DEBS" ] || [ -z "$(ls -A $KERNEL_DEBS/*.deb 2>/dev/null)" ]; then
    echo "ERROR: Kernel debs not found in $KERNEL_DEBS"
    echo "Build kernel first with: ./scripts/build_clockworkpi_kernel.sh"
    exit 1
fi

# Copy kernel debs to stage
install -d "${ROOTFS_DIR}/tmp/kernel-debs"
install -m 644 "$KERNEL_DEBS"/*.deb "${ROOTFS_DIR}/tmp/kernel-debs/"
BUILDEOF
            chmod +x "$CUSTOM_STAGE/00-run.sh"
            
            cat > "$CUSTOM_STAGE/01-run-chroot.sh" << 'CHROOTEOF'
#!/bin/bash -e

# Install kernel packages
echo "Installing custom kernel packages..."
apt-get update
apt-get install -y initramfs-tools
dpkg -i /tmp/kernel-debs/*.deb || apt-get install -f -y
rm -rf /tmp/kernel-debs

# Update initramfs
update-initramfs -u

echo "Custom kernel installed successfully"
CHROOTEOF
            chmod +x "$CUSTOM_STAGE/01-run-chroot.sh"
            ;;
    esac
fi

# Create desktop installation stage if specified
if [ "$DESKTOP" != "none" ]; then
    echo "Setting up desktop environment: $DESKTOP"
    DESKTOP_STAGE="$PI_GEN_DIR/stage3/06-desktop-environment"
    mkdir -p "$DESKTOP_STAGE"
    
    # Map desktop to task package
    case "$DESKTOP" in
        gnome)
            DESKTOP_PACKAGES="task-gnome-desktop"
            ;;
        kde)
            DESKTOP_PACKAGES="task-kde-desktop"
            ;;
        mate)
            DESKTOP_PACKAGES="task-mate-desktop"
            ;;
        xfce)
            DESKTOP_PACKAGES="task-xfce-desktop"
            ;;
        lxde)
            DESKTOP_PACKAGES="task-lxde-desktop"
            ;;
        lxqt)
            DESKTOP_PACKAGES="task-lxqt-desktop"
            ;;
        cinnamon)
            DESKTOP_PACKAGES="task-cinnamon-desktop"
            ;;
        gnome-flashback)
            DESKTOP_PACKAGES="task-gnome-flashback-desktop"
            ;;
        *)
            echo "ERROR: Unknown desktop environment: $DESKTOP"
            exit 1
            ;;
    esac
    
    echo "$DESKTOP_PACKAGES" > "$DESKTOP_STAGE/00-packages"
fi

# Clean any previous builds
if [ -d "$PI_GEN_DIR/work" ]; then
    echo "Cleaning previous build artifacts..."
    sudo rm -rf "$PI_GEN_DIR/work"
fi

if [ -d "$PI_GEN_DIR/deploy" ]; then
    echo "Cleaning previous deploy directory..."
    sudo rm -rf "$PI_GEN_DIR/deploy"
fi

# Run pi-gen build
echo ""
echo "================================================"
echo "Starting pi-gen build process..."
echo "================================================"
echo ""

# Run build script
sudo ./build.sh

# Check if build succeeded
if [ ! -d "$PI_GEN_DIR/deploy" ]; then
    echo "ERROR: Build failed - no deploy directory created" >&2
    exit 1
fi

# Copy output to our output directory
echo ""
echo "================================================"
echo "Copying built images to output directory..."
echo "================================================"

mkdir -p "$OUTPUT_DIR"
cp -v "$PI_GEN_DIR/deploy"/* "$OUTPUT_DIR/" 2>/dev/null || true

# List generated files
echo ""
echo "Generated files:"
ls -lh "$OUTPUT_DIR"

echo ""
echo "================================================"
echo "Image creation complete!"
echo "================================================"
echo "Output directory: $OUTPUT_DIR"

exit 0
