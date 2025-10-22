#!/bin/bash
set -e

############################################################################################################
# Debian trixie customization script for uConsole                                                         #
# Based on forum recipe - installs uConsole packages and system tweaks                                    #
############################################################################################################

OUTDIR="${1:-output}"
SUITE="trixie"
ARCH="${ARCH:-arm64}"
ROOTFS="$OUTDIR/rootfs-$SUITE-$ARCH"

echo "================================================"
echo "Setting up Debian trixie for uConsole"
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

# Install recommended packages for uConsole
echo "Installing recommended packages..."
chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    network-manager \
    wpasupplicant \
    wireless-tools \
    firmware-linux \
    firmware-linux-nonfree \
    firmware-misc-nonfree \
    firmware-realtek \
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
    ssh \
    curl \
    net-tools \
    alsa-utils \
    pulseaudio \
    linux-image-arm64"

# Install additional utilities
echo "Installing additional utilities..."
chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    i2c-tools \
    console-setup \
    keyboard-configuration"

# Clean up
echo "Cleaning up apt cache..."
chroot "$ROOTFS" /bin/bash -c "apt-get clean"
chroot "$ROOTFS" /bin/bash -c "rm -rf /var/lib/apt/lists/*"

# Create README for kernel installation
cat > "$ROOTFS/root/KERNEL_README.txt" << 'EOF'
========================================
uConsole Debian Trixie - Kernel Setup
========================================

This image requires the uConsole-specific kernel to be installed separately.
Follow the kernel installation steps from the uConsole documentation.

The kernel should include:
- Raspberry Pi 6.6.y base with uConsole patches
- Device tree overlays for clockworkpi-uconsole
- Audio remapping (pins_12_13)
- Display drivers

Kernel installation is not included in this rootfs build.
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
echo "Debian trixie setup complete!"
echo "Rootfs location: $ROOTFS"
echo "================================================"
echo ""
echo "Note: Kernel installation should be done separately."
echo "See $ROOTFS/root/KERNEL_README.txt for details."
