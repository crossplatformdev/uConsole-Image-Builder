#!/bin/bash
set -e

############################################################################################################
# Unified setup script for uConsole - supports jammy, trixie, bookworm, and popos                        #
# Always uses prebuilt kernel. For custom kernel builds, use ./scripts/build_clockworkpi_kernel.sh       #
############################################################################################################

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common_mounts.sh"
source "$SCRIPT_DIR/common_clockworkpi.sh"

# Parse arguments or use environment variables
if [ $# -ge 1 ]; then
    OUTDIR="$1"
    if [ $# -ge 2 ]; then
        SUITE="$2"
    fi
else
    OUTDIR="${OUTDIR:-output}"
fi

SUITE="${SUITE:-jammy}"

# Determine debootstrap suite (popos uses jammy)
if [[ "$SUITE" == "popos" ]]; then
    DEBOOTSTRAP_SUITE="jammy"
else
    DEBOOTSTRAP_SUITE="$SUITE"
fi

ARCH="${ARCH:-arm64}"
ROOTFS="$OUTDIR/rootfs-$DEBOOTSTRAP_SUITE-$ARCH"

echo "================================================"
echo "Setting up $SUITE for uConsole"
echo "================================================"
echo "Rootfs: $ROOTFS"
echo "================================================"

# Verify rootfs exists
if [ ! -d "$ROOTFS" ]; then
    echo "Error: Rootfs not found at $ROOTFS"
    echo "Please run scripts/build-image.sh first"
    exit 1
fi

# Ensure mounts are active
if ! mountpoint -q "$ROOTFS/proc"; then
    sudo mount --bind /proc "$ROOTFS/proc"
fi
if ! mountpoint -q "$ROOTFS/sys"; then
    sudo mount --bind /sys "$ROOTFS/sys"
fi
if ! mountpoint -q "$ROOTFS/dev"; then
    sudo mount --bind /dev "$ROOTFS/dev"
fi
if ! mountpoint -q "$ROOTFS/dev/pts"; then
    sudo mount --bind /dev/pts "$ROOTFS/dev/pts"
fi

# Create uconsole user
echo "Creating uconsole user..."
sudo chroot "$ROOTFS" /bin/bash -c "useradd -m -s /bin/bash -G sudo,adm,dialout,video,audio uconsole || true"
sudo chroot "$ROOTFS" /bin/bash -c "echo 'uconsole:uconsole' | chpasswd"

# Enable passwordless sudo for uconsole
sudo chroot "$ROOTFS" /bin/bash -c "echo 'uconsole ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uconsole"
sudo chroot "$ROOTFS" /bin/bash -c "chmod 0440 /etc/sudoers.d/uconsole"

# Install runtime packages based on suite
echo "Installing runtime packages for $SUITE..."

# Common packages for all suites
COMMON_PACKAGES="network-manager wpasupplicant wireless-tools bluez bluez-tools \
                 python3 python3-pip build-essential git vim nano htop curl \
                 net-tools alsa-utils pulseaudio"

if [[ "$SUITE" == "trixie" ]] || [[ "$SUITE" == "bookworm" ]]; then
    # Debian trixie/bookworm packages (Debian-specific firmware)
    sudo chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        $COMMON_PACKAGES \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree \
        firmware-realtek \
        ssh \
        linux-image-arm64"
else
    # Ubuntu/Pop!_OS packages (Ubuntu-specific packages)
    UBUNTU_PACKAGES="$COMMON_PACKAGES linux-firmware openssh-server wget"
    
    if [[ "$SUITE" == "popos" ]] || [[ "$SUITE" == "jammy" ]]; then
        # Pop!_OS and Jammy specific packages
        sudo chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
            $UBUNTU_PACKAGES \
            python3-lgpio \
            gnome-terminal \
            dbus"
    else
        # Other Ubuntu variants (fallback)
        sudo chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
            $UBUNTU_PACKAGES"
    fi
fi

# Install additional utilities common to all
echo "Installing additional utilities..."
sudo chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    i2c-tools \
    console-setup \
    keyboard-configuration"

# Pop!_OS specific branding
if [[ "$SUITE" == "popos" ]]; then
    echo "Configuring Pop!_OS branding..."
    chroot "$ROOTFS" /bin/bash -c "echo 'Pop!_OS 22.04 LTS for uConsole' > /etc/issue"
    chroot "$ROOTFS" /bin/bash -c "echo 'Pop!_OS 22.04 LTS for uConsole \\\n \\\l' > /etc/issue.net"
    
    cat > "$ROOTFS/etc/os-release" << 'EOF'
NAME="Pop!_OS"
VERSION="22.04 LTS"
ID=pop
ID_LIKE="ubuntu debian"
PRETTY_NAME="Pop!_OS 22.04 LTS"
VERSION_ID="22.04"
HOME_URL="https://pop.system76.com"
SUPPORT_URL="https://support.system76.com"
BUG_REPORT_URL="https://github.com/pop-os/pop/issues"
PRIVACY_POLICY_URL="https://system76.com/privacy"
VERSION_CODENAME=jammy
UBUNTU_CODENAME=jammy
LOGO=distributor-logo-pop-os
EOF
    
    cat > "$ROOTFS/etc/lsb-release" << 'EOF'
DISTRIB_ID=Pop
DISTRIB_RELEASE=22.04
DISTRIB_CODENAME=jammy
DISTRIB_DESCRIPTION="Pop!_OS 22.04 LTS"
EOF
fi

# Kernel handling - always use prebuilt kernel from clockworkpi/apt
# For custom kernel builds, use Docker: ./scripts/build_clockworkpi_kernel.sh
echo "================================================"
echo "Using prebuilt kernel from clockworkpi/apt"
echo "================================================"

# Setup ClockworkPi repository using common function
setup_clockworkpi_repository "$ROOTFS" "bookworm"
chroot "$ROOTFS" /bin/bash -c "apt-get install -y initramfs-tools"
chroot "$ROOTFS" /bin/bash -c "apt-get install -y uconsole-kernel-cm4-rpi clockworkpi-audio clockworkpi-cm-firmware"

echo "Prebuilt kernel repository configured"
echo "Note: To build custom kernel, use: ./scripts/build_clockworkpi_kernel.sh"

# Per-suite wait timing differences (as mentioned in original scripts)
# These wait times may be needed for certain operations to complete
if [[ "$SUITE" == "trixie" ]] || [[ "$SUITE" == "bookworm" ]]; then
    echo "Applying Debian-specific wait timing..."
    sleep 1
elif [[ "$SUITE" == "popos" ]]; then
    echo "Applying Pop!_OS-specific wait timing..."
    sleep 1
else
    echo "Applying Ubuntu-specific wait timing..."
    sleep 1
fi

# Clean up apt cache
echo "Cleaning up apt cache..."
sudo chroot "$ROOTFS" /bin/bash -c "apt-get clean"
sudo chroot "$ROOTFS" /bin/bash -c "rm -rf /var/lib/apt/lists/*"

# Create README for kernel installation
cat > "$ROOTFS/root/KERNEL_README.txt" << EOF
========================================
uConsole $SUITE - Kernel Setup
========================================

This image was built with prebuilt kernel from ClockworkPi repository.

The kernel includes:
- Raspberry Pi 6.12.y base with uConsole patches
- Device tree overlays for clockworkpi-uconsole
- Audio remapping (pins_12_13)
- Display drivers

To build a custom kernel, use Docker:
  ./scripts/build_clockworkpi_kernel.sh

For more information about kernel configuration and installation,
refer to the uConsole documentation.
EOF

# Restore resolv.conf
if [ -f "$ROOTFS/etc/resolv.conf.bak" ]; then
    mv "$ROOTFS/etc/resolv.conf.bak" "$ROOTFS/etc/resolv.conf"
fi

# Unmount system directories
echo "Unmounting system directories..."
sudo umount "$ROOTFS/dev/pts" || true
sudo umount "$ROOTFS/dev" || true
sudo umount "$ROOTFS/proc" || true
sudo umount "$ROOTFS/sys" || true

echo "================================================"
echo "$SUITE setup complete!"
echo "Rootfs location: $ROOTFS"
echo "Kernel: Prebuilt from ClockworkPi repository"
echo "================================================"
