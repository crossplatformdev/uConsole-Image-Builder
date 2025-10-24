#!/bin/bash
#
# common_clockworkpi.sh - Reusable functions for ClockworkPi apt repository setup
#
# This script provides functions for configuring the ClockworkPi apt repository
# and installing ClockworkPi packages.
#

set -e

#
# Add ClockworkPi apt repository to a rootfs
# Usage: add_clockworkpi_repo <rootfs_dir> [suite]
# Arguments:
#   rootfs_dir: Path to the mounted rootfs
#   suite: Distribution suite (default: bookworm)
#
add_clockworkpi_repo() {
    local rootfs_dir="$1"
    local suite="${2:-bookworm}"
    
    if [ -z "$rootfs_dir" ]; then
        echo "ERROR: Rootfs directory required" >&2
        return 1
    fi
    
    if [ ! -d "$rootfs_dir" ]; then
        echo "ERROR: Rootfs directory not found: $rootfs_dir" >&2
        return 1
    fi
    
    echo "Adding ClockworkPi apt repository..."
    
    # Add ClockworkPi GPG key
    echo "  - Adding GPG key..."
    if ! chroot "$rootfs_dir" /bin/bash -c "
        wget -q -O- https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg | \
        gpg --dearmor | \
        tee /etc/apt/trusted.gpg.d/clockworkpi.gpg > /dev/null
    " 2>/dev/null; then
        echo "  - Trying alternative method for GPG key..." >&2
        # Alternative: Download key on host and copy it
        wget -q -O /tmp/clockworkpi-key.gpg https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg
        gpg --dearmor < /tmp/clockworkpi-key.gpg > "$rootfs_dir/etc/apt/trusted.gpg.d/clockworkpi.gpg"
        rm -f /tmp/clockworkpi-key.gpg
    fi
    
    # The ClockworkPi repository uses Debian bookworm packages
    local repo_suite="bookworm"
    
    # Add apt repository
    echo "  - Adding apt sources list..."
    chroot "$rootfs_dir" /bin/bash -c "
        echo 'deb [arch=arm64] https://raw.githubusercontent.com/clockworkpi/apt/main/debian stable main' | \
        tee /etc/apt/sources.list.d/clockworkpi.list > /dev/null
    "
    
    echo "ClockworkPi apt repository configured"
    return 0
}

#
# Install ClockworkPi kernel packages
# Usage: install_clockworkpi_kernel_packages <rootfs_dir>
# Arguments:
#   rootfs_dir: Path to the mounted rootfs
#
install_clockworkpi_kernel_packages() {
    local rootfs_dir="$1"
    
    if [ -z "$rootfs_dir" ]; then
        echo "ERROR: Rootfs directory required" >&2
        return 1
    fi
    
    echo "Installing ClockworkPi kernel packages..."
    
    # Update apt cache
    echo "  - Updating apt cache..."
    chroot "$rootfs_dir" /bin/bash -c "apt-get update"
    
    # Install kernel dependencies
    echo "  - Installing kernel dependencies..."
    chroot "$rootfs_dir" /bin/bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y initramfs-tools
    "
    
    # Install ClockworkPi kernel packages
    echo "  - Installing ClockworkPi packages..."
    if ! chroot "$rootfs_dir" /bin/bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            uconsole-kernel-cm4-rpi \
            clockworkpi-audio \
            clockworkpi-cm-firmware
    " 2>/dev/null; then
        echo "  - Retrying with --allow-unauthenticated..." >&2
        chroot "$rootfs_dir" /bin/bash -c "
            DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated \
                uconsole-kernel-cm4-rpi \
                clockworkpi-audio \
                clockworkpi-cm-firmware
        "
    fi
    
    echo "ClockworkPi kernel packages installed"
    return 0
}

# Export functions for use in other scripts
export -f add_clockworkpi_repo
export -f install_clockworkpi_kernel_packages
