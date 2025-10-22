#!/bin/bash
set -e

############################################################################################################
# Ubuntu 22.04 (jammy) customization script for uConsole                                                  #
# Based on the original project script style for Ubuntu images                                            #
############################################################################################################

OUTDIR="${1:-output}"
SUITE="jammy"
ARCH="${ARCH:-arm64}"
ROOTFS="$OUTDIR/rootfs-$SUITE-$ARCH"

echo "================================================"
echo "Setting up Ubuntu 22.04 (jammy) for uConsole"
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

# Install minimal runtime packages following original script style
echo "Installing minimal runtime packages..."
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
    pulseaudio"

# Install additional utilities
echo "Installing additional development tools..."
chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    i2c-tools \
    console-setup \
    keyboard-configuration"

# Clean up apt cache
echo "Cleaning up apt cache..."
chroot "$ROOTFS" /bin/bash -c "apt-get clean"
chroot "$ROOTFS" /bin/bash -c "rm -rf /var/lib/apt/lists/*"

# Create README for kernel installation
cat > "$ROOTFS/root/KERNEL_README.txt" << 'EOF'
========================================
uConsole Ubuntu 22.04 - Kernel Setup
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
echo "Ubuntu 22.04 setup complete!"
echo "Rootfs location: $ROOTFS"
echo "================================================"
echo ""
echo "Note: Kernel installation should be done separately."
echo "See $ROOTFS/root/KERNEL_README.txt for details."
