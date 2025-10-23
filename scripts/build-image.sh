#!/bin/bash
set -e

############################################################################################################
# Unified build script for uConsole images using debootstrap                                              #
# Supports Debian 13 (trixie), Debian 12 (bookworm), and Ubuntu 22.04 (jammy)                            #
############################################################################################################

# Default configuration
SUITE="${SUITE:-trixie}"
ARCH="${ARCH:-arm64}"
OUTDIR="${1:-output}"

echo "================================================"
echo "uConsole Image Builder"
echo "================================================"
echo "Suite: $SUITE"
echo "Architecture: $ARCH"
echo "Output directory: $OUTDIR"
echo "================================================"

# Validate suite
#if [[ "$SUITE" != "trixie" ]] && [[ "$SUITE" != "jammy" ]]; then
    #echo "Error: SUITE must be 'trixie' or 'jammy'"
    #exit 1
#fi

# Create output directory
mkdir -p "$OUTDIR"
ROOTFS="$OUTDIR/rootfs-$SUITE-$ARCH"

# Clean up any existing rootfs
if [ -d "$ROOTFS" ]; then
    echo "Cleaning up existing rootfs..."
    rm -rf "$ROOTFS"
fi

# Install required packages
echo "Installing debootstrap and dependencies..."
apt-get update
apt-get install -y debootstrap qemu-user-static binfmt-support

# Determine repository URL based on suite
if [[ "$SUITE" == "jammy" ]]; then
    REPO_URL="http://ports.ubuntu.com/ubuntu-ports"
    # Run debootstrap
    echo "Running debootstrap for $SUITE ($ARCH)..."
    debootstrap --arch="$ARCH" --foreign "$SUITE" "$ROOTFS" "$REPO_URL"
elif [[ "$SUITE" == "popos" ]]; then
    wget https://iso.pop-os.org/22.04/arm64/raspi/4/pop-os_22.04_arm64_raspi_4.img.xz

    #Extract the image
    unxz pop-os_22.04_arm64_raspi_4.img.xz

    #Mount the image
    losetup -D
    losetup /dev/loop123 -P pop-os_22.04_arm64_raspi_4.img

    mount /dev/loop123p2 "$ROOTFS"
    mkdir "$ROOTFS/boot/firmware"
    mount /dev/loop123p1 "$ROOTFS/boot/firmware"
else
    REPO_URL="http://deb.debian.org/debian"
    # Run debootstrap
    echo "Running debootstrap for $SUITE ($ARCH)..."
    debootstrap --arch="$ARCH" --foreign "$SUITE" "$ROOTFS" "$REPO_URL"
fi

# Copy qemu-user-static for cross-architecture chroot
echo "Setting up QEMU for cross-architecture support..."
cp /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/"

# Complete second stage of debootstrap in chroot
echo "Running debootstrap second stage..."
chroot "$ROOTFS" /debootstrap/debootstrap --second-stage

# Bind mount system directories
echo "Binding system directories..."
mount --bind /proc "$ROOTFS/proc"
mount --bind /sys "$ROOTFS/sys"
mount --bind /dev "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"

# Backup and configure DNS resolution
if [ -f "$ROOTFS/etc/resolv.conf" ]; then
    mv "$ROOTFS/etc/resolv.conf" "$ROOTFS/etc/resolv.conf.bak"
fi
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

# Configure apt sources
echo "Configuring apt sources for $SUITE..."
if [[ "$SUITE" == "jammy" ]]; then
    cat > "$ROOTFS/etc/apt/sources.list" << EOF
deb http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse
EOF
elif [[ "$SUITE" == "bookworm" ]]; then
    cat > "$ROOTFS/etc/apt/sources.list" << EOF
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
else
    cat > "$ROOTFS/etc/apt/sources.list" << EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
fi

# Install minimal packages in chroot
echo "Installing minimal packages in chroot..."
chroot "$ROOTFS" /bin/bash -c "apt-get update"
chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    systemd \
    systemd-sysv \
    udev \
    sudo \
    locales \
    wget \
    ca-certificates \
    aptitude \
    tasksel \
    gnupg" 

# Configure locale
echo "Configuring locale..."
chroot "$ROOTFS" /bin/bash -c "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen"
chroot "$ROOTFS" /bin/bash -c "locale-gen"

# Set timezone
echo "Setting timezone..."
chroot "$ROOTFS" /bin/bash -c "ln -sf /usr/share/zoneinfo/UTC /etc/localtime"

# Set hostname
echo "uconsole" > "$ROOTFS/etc/hostname"

# Configure basic network
cat > "$ROOTFS/etc/hosts" << EOF
127.0.0.1       localhost
127.0.1.1       uconsole

# The following lines are desirable for IPv6 capable hosts
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

echo "Base rootfs created successfully at: $ROOTFS"
echo "To customize, run the unified setup script:"
echo "  sudo SUITE=<suite> RECOMPILE_KERNEL=<true|false> scripts/setup-suite.sh $OUTDIR"
echo "  Examples:"
echo "    - For trixie:   SUITE=trixie RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
echo "    - For bookworm: SUITE=bookworm RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
echo "    - For jammy:    SUITE=jammy RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
echo "    - For popos:    SUITE=popos RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
