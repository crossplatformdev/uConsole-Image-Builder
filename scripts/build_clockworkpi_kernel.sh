#!/bin/bash
#
# build_clockworkpi_kernel.sh - Build ClockworkPi kernel from source with ak-rex patch
#
# This script builds Linux kernel .deb packages for ClockworkPi uConsole devices.
# It clones the kernel source, applies the ak-rex patch, and builds Debian packages.
#
# Usage: build_clockworkpi_kernel.sh [output_dir]
#
# Environment Variables:
#   KERNEL_REPO - Kernel git repository URL (default: https://github.com/raspberrypi/linux.git)
#   KERNEL_BRANCH - Kernel branch to build (default: rpi-6.12.y)
#   KERNEL_LOCALVERSION - Local version string (default: -uconsole)
#   APPLY_PATCH - Whether to apply ak-rex patch (default: true)
#   PATCH_FILE - Path to ak-rex patch file (default: patches/ak-rex.patch)
#

set -e

# Configuration
KERNEL_REPO="${KERNEL_REPO:-https://github.com/raspberrypi/linux.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-rpi-6.12.y}"
KERNEL_LOCALVERSION="${KERNEL_LOCALVERSION:--raspi}"
APPLY_PATCH="${APPLY_PATCH:-true}"
OUTPUT_DIR="${1:-artifacts/kernel-debs}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_FILE="${PATCH_FILE:-$REPO_ROOT/patches/ak-rex.patch}"

echo "================================================"
echo "Building ClockworkPi Kernel from Source"
echo "================================================"
echo "Repository: $KERNEL_REPO"
echo "Branch: $KERNEL_BRANCH"
echo "Local Version: $KERNEL_LOCALVERSION"
echo "Apply Patch: $APPLY_PATCH"
echo "Output Directory: $OUTPUT_DIR"
echo "================================================"

# Ensure we're running with proper privileges
if [ "$EUID" -ne 0 ]; then
    echo "WARNING: Not running as root. Build may fail or produce unusable packages." >&2
    echo "Consider running with sudo if you encounter issues." >&2
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)

# Create build directory
BUILD_DIR="/tmp/kernel-build-$$"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Build directory: $BUILD_DIR"

# Install build dependencies
echo "Installing kernel build dependencies..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential \
        bc \
        bison \
        flex \
        libssl-dev \
        libncurses-dev \
        libelf-dev \
        kmod \
        cpio \
        rsync \
        git \
        fakeroot \
        dpkg-dev \
        debhelper \
        kernel-wedge \
        wget \
        crossbuild-essential-arm64 \
        ca-certificates
else
    echo "WARNING: apt-get not found. Please ensure build dependencies are installed." >&2
fi

# Clone kernel source
echo "Cloning kernel source..."
if [ -d "linux" ]; then
    echo "Removing existing linux directory..."
    rm -rf linux
fi

git clone --depth=1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" linux
cd linux

echo "Kernel source cloned ($(git describe --always))"

# Apply ak-rex patch if enabled
if [ "$APPLY_PATCH" = "true" ]; then
    echo "Checking for ak-rex patch..."
    
    if [ -f "$PATCH_FILE" ]; then
        # Check if it's an actual patch or just documentation
        if grep -q "^diff " "$PATCH_FILE" 2>/dev/null || grep -q "^--- " "$PATCH_FILE" 2>/dev/null; then
            echo "Applying ak-rex patch: $PATCH_FILE"
            
            ## Try using git apply first (is a .patch file)
            if patch -p1 < "$PATCH_FILE"; then
                echo "Patch applied successfully with patch command"
            else
                echo "ERROR: Failed to apply ak-rex patch" >&2
                exit 1
            fi
        else
            echo "WARNING: Patch file exists but appears to be documentation only"
            echo "Continuing without patch. To build with ak-rex support:"
            echo "  1. Obtain the actual ak-rex patch file"
            echo "  2. Place it at $PATCH_FILE"
            echo "  3. Re-run this script"
        fi
    else
        echo "WARNING: Patch file not found: $PATCH_FILE"
        echo "Continuing without patch. See patches/ak-rex.patch for instructions."
    fi
fi

# Configure kernel
echo "Configuring kernel..."
make ARCH=arm64 bcm2711_defconfig

# Optional: Enable additional modules for uConsole
# Uncomment and customize as needed:
# scripts/config --enable CONFIG_SOME_DRIVER
# scripts/config --module CONFIG_ANOTHER_DRIVER

# Build kernel .deb packages
echo "Building kernel packages (this will take a while)..."
echo "Using $(nproc) parallel jobs"

# Build using bindeb-pkg target (creates binary .deb packages only)
# This is faster than deb-pkg which also creates source packages
make deb-pkg -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION="-raspi"


# Move .deb files to output directory
echo "Collecting kernel packages..."
cd "$BUILD_DIR"

# Find all .deb files
DEB_COUNT=0
for deb in *.deb; do
    if [ -f "$deb" ]; then
        echo "Found: $deb ($(du -h "$deb" | cut -f1))"
        cp "$deb" "$OUTPUT_DIR/"
        DEB_COUNT=$((DEB_COUNT + 1))
    fi
done

if [ $DEB_COUNT -eq 0 ]; then
    echo "ERROR: No .deb packages found!" >&2
    exit 1
fi

echo "================================================"
echo "Kernel build complete!"
echo "================================================"
echo "Output directory: $OUTPUT_DIR"
echo "Packages created: $DEB_COUNT"
echo ""
ls -lh "$OUTPUT_DIR"/*.deb
echo ""

# Create installation instructions
cat > "$OUTPUT_DIR/INSTALL.txt" << EOF
ClockworkPi uConsole Kernel Packages
====================================

Build Information:
- Kernel Repository: $KERNEL_REPO
- Branch: $KERNEL_BRANCH
- Commit: $(cd "$BUILD_DIR/linux" && git describe --always)
- Local Version: $KERNEL_LOCALVERSION
- Patch Applied: $APPLY_PATCH
- Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Package Installation:
--------------------

To install these kernel packages on your uConsole:

1. Copy the .deb files to your uConsole:
   scp *.deb uconsole@your-uconsole-ip:/tmp/

2. On your uConsole, install the packages:
   cd /tmp
   sudo dpkg -i linux-*.deb
   sudo apt-get install -f

3. Reboot to use the new kernel:
   sudo reboot

Packages in this directory:
---------------------------
$(ls -1 "$OUTPUT_DIR"/*.deb 2>/dev/null | xargs -n1 basename || echo "No packages found")

For more information:
- https://github.com/clockworkpi/uConsole
- https://github.com/clockworkpi/apt
EOF

echo "Installation instructions: $OUTPUT_DIR/INSTALL.txt"
echo ""

# Optional: Clean up build directory
if [ "${KEEP_BUILD:-false}" != "true" ]; then
    echo "Cleaning up build directory..."
    cd /
    rm -rf "$BUILD_DIR"
    echo "Build directory removed"
else
    echo "Build directory preserved: $BUILD_DIR"
fi

echo "Done!"
exit 0
