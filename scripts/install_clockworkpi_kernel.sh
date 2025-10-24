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

# Get script directory for sourcing common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common ClockworkPi functions
source "$SCRIPT_DIR/common_clockworkpi.sh"

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

# Add ClockworkPi apt repository and install packages using common functions
add_clockworkpi_repo "$ROOTFS_DIR" "$SUITE"
install_clockworkpi_kernel_packages "$ROOTFS_DIR"

# Create a kernel info file
echo "Creating kernel installation record..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c "
cat > /root/KERNEL_INFO.txt << 'EOF'
========================================
ClockworkPi uConsole Kernel Information
========================================

Installation Method: Prebuilt packages from ClockworkPi apt repository
Repository: https://github.com/clockworkpi/apt
Suite: bookworm

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
