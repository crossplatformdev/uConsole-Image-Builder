#!/bin/bash
#
# install_clockworkpi_kernel.sh - Install prebuilt ClockworkPi kernel packages
#
# This script configures the ClockworkPi apt repository and installs
# prebuilt kernel packages into a mounted rootfs.
#
# Usage: install_clockworkpi_kernel.sh <rootfs_mount_dir> [suite]
#

set -e

ROOTFS_DIR="${1:-}"
SUITE="${2:-bookworm}"

if [ -z "$ROOTFS_DIR" ]; then
    echo "ERROR: Rootfs mount directory required" >&2
    echo "Usage: $0 <rootfs_mount_dir> [suite]" >&2
    exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "ERROR: Rootfs directory not found: $ROOTFS_DIR" >&2
    exit 1
fi

echo "================================================"
echo "Installing ClockworkPi Kernel (Prebuilt)"
echo "================================================"
echo "Rootfs: $ROOTFS_DIR"
echo "Suite: $SUITE"
echo "================================================"

# Ensure we're running with proper privileges
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)" >&2
    exit 1
fi

# Add ClockworkPi GPG key
echo "Adding ClockworkPi repository GPG key..."
if ! chroot "$ROOTFS_DIR" /bin/bash -c "
    wget -q -O- https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/clockworkpi.gpg > /dev/null
"; then
    echo "WARNING: Failed to add GPG key via wget, trying alternative method..." >&2
    # Alternative: Download key on host and copy it
    wget -q -O /tmp/clockworkpi-key.gpg https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg
    gpg --dearmor < /tmp/clockworkpi-key.gpg > "$ROOTFS_DIR/etc/apt/trusted.gpg.d/clockworkpi.gpg"
    rm -f /tmp/clockworkpi-key.gpg
fi

# Add ClockworkPi apt repository
echo "Adding ClockworkPi apt repository..."

# Determine which repository to use based on suite
# The ClockworkPi repository uses Debian bookworm packages
REPO_SUITE="bookworm"

sudo chroot "$ROOTFS_DIR" /bin/bash -c "
    echo 'deb [arch=arm64] https://raw.githubusercontent.com/clockworkpi/apt/main/debian stable main' | \
    tee /etc/apt/sources.list.d/clockworkpi.list
"

# Update apt cache
echo "Updating apt cache..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c "
    apt-get update
"

# Install kernel build dependencies first
echo "Installing kernel dependencies..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c "
    DEBIAN_FRONTEND=noninteractive apt-get install -y initramfs-tools
"

# Install ClockworkPi kernel packages
echo "Installing ClockworkPi kernel packages..."

# Try to install kernel packages (may need --allow-unauthenticated if GPG key setup fails)
if ! chroot "$ROOTFS_DIR" /bin/bash -c "
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        uconsole-kernel-cm4-rpi \
        clockworkpi-audio \
        clockworkpi-cm-firmware
"; then
    echo "WARNING: Standard installation failed, trying with --allow-unauthenticated..." >&2
    chroot "$ROOTFS_DIR" /bin/bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated \
            uconsole-kernel-cm4-rpi \
            clockworkpi-audio \
            clockworkpi-cm-firmware
    "
fi

# Create a kernel info file
echo "Creating kernel installation record..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c "
cat > /root/KERNEL_INFO.txt << 'EOF'
========================================
ClockworkPi uConsole Kernel Information
========================================

Installation Method: Prebuilt packages from ClockworkPi apt repository
Repository: https://github.com/clockworkpi/apt
Suite: $REPO_SUITE

Installed Packages:
- uconsole-kernel-cm4-rpi: Linux kernel for uConsole CM4
- clockworkpi-audio: Audio configuration and drivers
- clockworkpi-cm-firmware: Firmware files for ClockworkPi devices

The kernel includes:
- Raspberry Pi 6.x base kernel
- ClockworkPi uConsole device support
- Device tree overlays for uConsole hardware
- Audio remapping for uConsole speaker
- Display and GPIO drivers

For more information:
- https://github.com/clockworkpi/uConsole
- https://github.com/clockworkpi/apt
EOF
"

echo "================================================"
echo "ClockworkPi kernel installation complete!"
echo "================================================"

# List installed kernel packages
echo "Installed kernel packages:"
sudo chroot "$ROOTFS_DIR" /bin/bash -c "dpkg -l | grep -E '(uconsole|clockworkpi)'" || true

exit 0
