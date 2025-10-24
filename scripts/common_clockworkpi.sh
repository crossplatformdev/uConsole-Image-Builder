#!/bin/bash
#
# common_clockworkpi.sh - Helper functions for ClockworkPi repository configuration
#
# This script provides reusable functions for:
# - Adding ClockworkPi GPG keys
# - Configuring ClockworkPi apt repositories
# - Installing ClockworkPi packages
#

set -e

#
# Add ClockworkPi repository GPG key to a rootfs
# Usage: add_clockworkpi_gpg_key <rootfs_dir>
#
add_clockworkpi_gpg_key() {
    local rootfs_dir="$1"
    
    if [ -z "$rootfs_dir" ]; then
        echo "ERROR: Rootfs directory required" >&2
        return 1
    fi
    
    if [ ! -d "$rootfs_dir" ]; then
        echo "ERROR: Rootfs directory not found: $rootfs_dir" >&2
        return 1
    fi
    
    echo "Adding ClockworkPi repository GPG key..."
    
    # Try to add key via chroot (preferred method)
    if chroot "$rootfs_dir" /bin/bash -c "
        wget -q -O- https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg | \
        gpg --dearmor | \
        tee /etc/apt/trusted.gpg.d/clockworkpi.gpg > /dev/null
    " 2>/dev/null; then
        echo "GPG key added successfully via chroot"
        return 0
    fi
    
    # Fallback: Download key on host and copy it
    echo "WARNING: Failed to add GPG key via wget in chroot, trying alternative method..." >&2
    local temp_key="/tmp/clockworkpi-key-$$.gpg"
    
    if wget -q -O "$temp_key" https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg; then
        gpg --dearmor < "$temp_key" > "$rootfs_dir/etc/apt/trusted.gpg.d/clockworkpi.gpg"
        rm -f "$temp_key"
        echo "GPG key added successfully via host download"
        return 0
    else
        echo "ERROR: Failed to download ClockworkPi GPG key" >&2
        rm -f "$temp_key"
        return 1
    fi
}

#
# Add ClockworkPi apt repository to a rootfs
# Usage: add_clockworkpi_repository <rootfs_dir> [suite]
# Default suite: bookworm
#
add_clockworkpi_repository() {
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
    
    # Main repository (stable)
    chroot "$rootfs_dir" /bin/bash -c "
        echo 'deb [arch=arm64] https://raw.githubusercontent.com/clockworkpi/apt/main/debian stable main' | \
        tee /etc/apt/sources.list.d/clockworkpi.list
    "
    
    # Add suite-specific repository if needed
    if [ "$suite" != "stable" ] && [ -n "$suite" ]; then
        echo "Adding suite-specific repository for $suite..."
        chroot "$rootfs_dir" /bin/bash -c "
            echo \"deb [arch=arm64] https://raw.githubusercontent.com/clockworkpi/apt/main/$suite stable main\" | \
            tee -a /etc/apt/sources.list.d/clockworkpi.list
        "
    fi
    
    echo "ClockworkPi repository configured"
    return 0
}

#
# Setup ClockworkPi repository (GPG key + repository)
# Usage: setup_clockworkpi_repository <rootfs_dir> [suite]
#
setup_clockworkpi_repository() {
    local rootfs_dir="$1"
    local suite="${2:-bookworm}"
    
    # Add GPG key
    add_clockworkpi_gpg_key "$rootfs_dir" || return 1
    
    # Add repository
    add_clockworkpi_repository "$rootfs_dir" "$suite" || return 1
    
    # Update apt cache
    echo "Updating apt cache..."
    chroot "$rootfs_dir" /bin/bash -c "apt-get update" || {
        echo "WARNING: apt-get update failed" >&2
        return 1
    }
    
    echo "ClockworkPi repository setup complete"
    return 0
}

# Export functions for use in other scripts
export -f add_clockworkpi_gpg_key
export -f add_clockworkpi_repository
export -f setup_clockworkpi_repository
