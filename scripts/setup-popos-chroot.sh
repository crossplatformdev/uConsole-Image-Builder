#!/bin/bash
set -e

############################################################################################################
# Pop!_OS 22.04 customization script for uConsole                                                         #
# Based on Ubuntu 22.04 (jammy) with Pop!_OS specific configurations                                      #
############################################################################################################

OUTDIR="${1:-output}"
SUITE="jammy"
ARCH="${ARCH:-arm64}"
ROOTFS="$OUTDIR/rootfs-$SUITE-$ARCH"

echo "================================================"
echo "Setting up Pop!_OS 22.04 for uConsole"
echo "================================================"
echo "Rootfs: $ROOTFS"
echo "================================================"

# Verify rootfs exists
if [ ! -d "$ROOTFS" ]; then
    echo "Error: Rootfs not found at $ROOTFS"
    echo "Please run scripts/build-image.sh with SUITE=jammy first"
    exit 1
fi

# Ensure mounts are active
if ! mountpoint -q "$ROOTFS/proc"; then
    mount --bind /proc "$ROOTFS/proc"
fi
if ! mountpoint -q "$ROOTFS/sys"; then
    mount --bind /sys "$ROOTFS/sys"
fi
if ! mountpoint -q "$ROOTFS/dev"; then
    mount --bind /dev "$ROOTFS/dev"
fi
if ! mountpoint -q "$ROOTFS/dev/pts"; then
    mount --bind /dev/pts "$ROOTFS/dev/pts"
fi

# Create uconsole user
echo "Creating uconsole user..."
chroot "$ROOTFS" /bin/bash -c "useradd -m -s /bin/bash -G sudo,adm,dialout,video,audio uconsole || true"
chroot "$ROOTFS" /bin/bash -c "echo 'uconsole:uconsole' | chpasswd"

# Enable passwordless sudo for uconsole
chroot "$ROOTFS" /bin/bash -c "echo 'uconsole ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uconsole"
chroot "$ROOTFS" /bin/bash -c "chmod 0440 /etc/sudoers.d/uconsole"

# Install Pop!_OS themed packages and runtime dependencies
echo "Installing Pop!_OS packages and runtime dependencies..."
chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    network-manager \
    wpasupplicant \
    wireless-tools \
    linux-firmware \
    bluez \
    bluez-tools \
    python3 \
    python3-pip \
    python3-lgpio \
    build-essential \
    git \
    vim \
    nano \
    htop \
    openssh-server \
    curl \
    wget \
    net-tools \
    alsa-utils \
    pulseaudio \
    gnome-terminal"

# Install additional utilities
echo "Installing additional development tools..."
chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    i2c-tools \
    console-setup \
    keyboard-configuration \
    dbus"

# Set up Pop!_OS branding
echo "Configuring Pop!_OS branding..."
chroot "$ROOTFS" /bin/bash -c "echo 'Pop!_OS 22.04 LTS for uConsole' > /etc/issue"
chroot "$ROOTFS" /bin/bash -c "echo 'Pop!_OS 22.04 LTS for uConsole \\\n \\\l' > /etc/issue.net"

# Create os-release for Pop!_OS identification
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

# Create lsb-release
cat > "$ROOTFS/etc/lsb-release" << 'EOF'
DISTRIB_ID=Pop
DISTRIB_RELEASE=22.04
DISTRIB_CODENAME=jammy
DISTRIB_DESCRIPTION="Pop!_OS 22.04 LTS"
EOF

# Clean up apt cache
echo "Cleaning up apt cache..."
chroot "$ROOTFS" /bin/bash -c "apt-get clean"
chroot "$ROOTFS" /bin/bash -c "rm -rf /var/lib/apt/lists/*"

# Create README for kernel installation
cat > "$ROOTFS/root/KERNEL_README.txt" << 'EOF'
========================================
uConsole Pop!_OS 22.04 - Kernel Setup
========================================

This image requires the uConsole-specific kernel to be installed separately.
Follow the kernel installation steps from the uConsole documentation.

The kernel should include:
- Raspberry Pi 6.6.y or 6.9.y base with uConsole patches
- Device tree overlays for clockworkpi-uconsole
- Audio remapping (pins_12_13)
- Display drivers

Kernel installation is not included in this rootfs build.

To install the uConsole GPIO package and kernel, you can:
1. Copy the uconsole-cm4-gpio.deb and kernel .deb files to the rootfs
2. Install them using dpkg -i *.deb
3. Configure /boot/firmware/config.txt with uConsole-specific settings

Refer to the original create_image.sh for detailed kernel build and installation steps.
EOF

# Restore resolv.conf
if [ -f "$ROOTFS/etc/resolv.conf.bak" ]; then
    mv "$ROOTFS/etc/resolv.conf.bak" "$ROOTFS/etc/resolv.conf"
fi

# Unmount system directories
echo "Unmounting system directories..."
umount "$ROOTFS/dev/pts" || true
umount "$ROOTFS/dev" || true
umount "$ROOTFS/proc" || true
umount "$ROOTFS/sys" || true

echo "================================================"
echo "Pop!_OS 22.04 setup complete!"
echo "Rootfs location: $ROOTFS"
echo "================================================"
echo ""
echo "Note: Kernel installation should be done separately."
echo "See $ROOTFS/root/KERNEL_README.txt for details."
