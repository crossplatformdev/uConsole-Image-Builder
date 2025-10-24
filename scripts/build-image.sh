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
    rm -rf "$ROOTFS/**"
fi

# Use environment variables for image name and link
IMAGE_NAME="${IMAGE_NAME:-pop-os_22.04_arm64_raspi_4.img.xz}"
IMAGE_LINK="${IMAGE_LINK:-https://iso.pop-os.org/22.04/arm64/raspi/4/pop-os_22.04_arm64_raspi_4.img.xz}"

# Download the image redirecting output to /dev/null
echo "Downloading image from $IMAGE_LINK..."
wget "$IMAGE_LINK" -O "$IMAGE_NAME" >/dev/null 2>&1

#Extract the image
unxz "$IMAGE_NAME"

#Mount the image
sudo losetup -D

# Derive IMAGE_NAME_WITHOUT_XZ by removing .xz extension
IMAGE_NAME_WITHOUT_XZ="${IMAGE_NAME%.xz}"

# Find a free loop device and set it up with partitions
LOOP_DEVICE=$(losetup -f)
sudo losetup "$LOOP_DEVICE" -P "$IMAGE_NAME_WITHOUT_XZ"

if [ ! -d "$ROOTFS" ]; then
   mkdir -p "$ROOTFS"
fi

sudo mount "${LOOP_DEVICE}p2" "$ROOTFS"

if [ ! -d "$ROOTFS/boot/firmware" ]; then
   mkdir -p "$ROOTFS/boot/firmware"
fi

sudo mount "${LOOP_DEVICE}p1" "$ROOTFS/boot/firmware"


sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /dev/pts "$ROOTFS/dev/pts"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"

# Backup and configure DNS resolution
sudo mv "$ROOTFS/etc/resolv.conf" "$ROOTFS/etc/resolv.conf.bak" || true
sudo cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

# Configure apt sources (skip for image-based distributions)
if [[ "$SUITE" != "popos" ]]; then
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
fi 

# Configure locale
echo "Configuring locale..."
chroot "$ROOTFS" /bin/bash -c "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen"
chroot "$ROOTFS" /bin/bash -c "locale-gen"

# Set timezone
echo "Setting timezone..."
chroot "$ROOTFS" /bin/bash -c "ln -sf /usr/share/zoneinfo/UTC /etc/localtime"

# Set hostname
echo "uconsole" > "$ROOTFS/etc/hostname"

# Configure resolv.conf
sudo mv "$ROOTFS/etc/resolv.conf.bak" "$ROOTFS/etc/resolv.conf" || true

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
echo "  SUITE=<suite> RECOMPILE_KERNEL=<true|false> scripts/setup-suite.sh $OUTDIR"
echo "  Examples:"
echo "    - For trixie:   SUITE=trixie RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
echo "    - For bookworm: SUITE=bookworm RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
echo "    - For jammy:    SUITE=jammy RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
echo "    - For popos:    SUITE=popos RECOMPILE_KERNEL=false scripts/setup-suite.sh $OUTDIR"
