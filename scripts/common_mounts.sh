#!/bin/bash
#
# common_mounts.sh - Helper functions for mounting and managing loop devices
#
# This script provides reusable functions for:
# - Setting up loop devices with losetup
# - Creating partition mappings with kpartx
# - Mounting partitions (boot and root)
# - Bind-mounting system directories for chroot
# - Cleanup and unmounting
#

set -e

# Global variables for tracking mounts and devices
LOOP_DEVICE=""
sudo mount_DIR=""
BOOT_MOUNTED=false
ROOT_MOUNTED=false
BINDS_MOUNTED=false

#
# Setup a loop device for an image file
# Usage: setup_loop_device <image_file>
# Sets: LOOP_DEVICE
#
setup_loop_device() {
    local image_file="$1"
    
    if [ ! -f "$image_file" ]; then
        echo "ERROR: Image file not found: $image_file" >&2
        return 1
    fi
    
    echo "Setting up loop device for $image_file..."
    
    # Find next available loop device and set it up
    LOOP_DEVICE=$(losetup -f)
    sudo losetup -P "$LOOP_DEVICE" "$image_file"
    
    # Wait for partition devices to appear
    sleep 2
    
    # Refresh partition table
    partprobe "$LOOP_DEVICE" 2>/dev/null || true
    
    echo "Loop device ready: $LOOP_DEVICE"
    ls -l "${LOOP_DEVICE}"* || true
    
    return 0
}

#
# Setup kpartx mappings for a loop device
# Usage: setup_kpartx <loop_device>
#
setup_kpartx() {
    local loop_dev="$1"
    
    echo "Setting up kpartx mappings for $loop_dev..."
    kpartx -av "$loop_dev"
    
    # Wait for device mapper devices to appear
    sleep 2
    
    # List the mappings
    kpartx -l "$loop_dev"
    
    return 0
}

#
# Mount root and boot partitions
# Usage: mount_partitions <loop_device> <mount_dir> [boot_partition_number] [root_partition_number]
# Defaults: boot=1, root=2
#
sudo mount_partitions() {
    local loop_dev="$1"
    local mount_dir="$2"
    local boot_part="${3:-1}"
    local root_part="${4:-2}"
    
sudo mount_DIR="$mount_dir"
    
    # Create mount directory
    mkdir -p "$MOUNT_DIR"
    
    # Mount root partition
    echo "Mounting root partition (${loop_dev}p${root_part})..."
    if [ -e "${loop_dev}p${root_part}" ]; then
sudo mount "${loop_dev}p${root_part}" "$MOUNT_DIR"
        ROOT_MOUNTED=true
        echo "Root partition mounted at $MOUNT_DIR"
    else
        echo "ERROR: Root partition ${loop_dev}p${root_part} not found" >&2
        return 1
    fi
    
    # Create boot mount point
    mkdir -p "$MOUNT_DIR/boot/firmware"
    
    # Mount boot partition
    echo "Mounting boot partition (${loop_dev}p${boot_part})..."
    if [ -e "${loop_dev}p${boot_part}" ]; then
sudo mount "${loop_dev}p${boot_part}" "$MOUNT_DIR/boot/firmware"
        BOOT_MOUNTED=true
        echo "Boot partition mounted at $MOUNT_DIR/boot/firmware"
    else
        echo "WARNING: Boot partition ${loop_dev}p${boot_part} not found" >&2
    fi
    
    return 0
}

#
# Bind mount system directories for chroot
# Usage: bind_mount_system <mount_dir>
#
bind_mount_system() {
    local mount_dir="$1"
    
    echo "Bind mounting system directories..."
    
sudo mount --bind /dev "$mount_dir/dev"
sudo mount --bind /dev/pts "$mount_dir/dev/pts"
sudo mount --bind /proc "$mount_dir/proc"
sudo mount --bind /sys "$mount_dir/sys"
sudo mount --bind /run "$mount_dir/run" || true  # May not exist on all systems
    
    BINDS_MOUNTED=true
    
    echo "System directories bind mounted"
    return 0
}

#
# Copy qemu-user-static for cross-architecture chroot
# Usage: setup_qemu_chroot <mount_dir> [arch]
# Default arch: aarch64
#
setup_qemu_chroot() {
    local mount_dir="$1"
    local arch="${2:-aarch64}"
    
    local qemu_binary="/usr/bin/qemu-${arch}-static"
    
    if [ ! -f "$qemu_binary" ]; then
        echo "ERROR: QEMU binary not found: $qemu_binary" >&2
        echo "Install qemu-user-static package" >&2
        return 1
    fi
    
    echo "Copying QEMU binary for chroot..."
    mkdir -p "$mount_dir/usr/bin"
    cp "$qemu_binary" "$mount_dir/usr/bin/"
    
    echo "QEMU binary ready for chroot"
    return 0
}

#
# Cleanup and unmount everything
# Usage: cleanup_mounts
#
cleanup_mounts() {
    echo "Cleaning up mounts and devices..."
    
    # Unmount bind mounts
    if [ "$BINDS_MOUNTED" = true ] && [ -n "$MOUNT_DIR" ]; then
        echo "Unmounting bind mounts..."
sudo umount "$MOUNT_DIR/run" 2>/dev/null || true
sudo umount "$MOUNT_DIR/sys" 2>/dev/null || true
sudo umount "$MOUNT_DIR/proc" 2>/dev/null || true
sudo umount "$MOUNT_DIR/dev/pts" 2>/dev/null || true
sudo umount "$MOUNT_DIR/dev" 2>/dev/null || true
        BINDS_MOUNTED=false
    fi
    
    # Unmount boot partition
    if [ "$BOOT_MOUNTED" = true ] && [ -n "$MOUNT_DIR" ]; then
        echo "Unmounting boot partition..."
sudo umount "$MOUNT_DIR/boot/firmware" 2>/dev/null || true
        BOOT_MOUNTED=false
    fi
    
    # Unmount root partition
    if [ "$ROOT_MOUNTED" = true ] && [ -n "$MOUNT_DIR" ]; then
        echo "Unmounting root partition..."
sudo umount "$MOUNT_DIR" 2>/dev/null || true
        ROOT_MOUNTED=false
    fi
    
    # Remove kpartx mappings
    if [ -n "$LOOP_DEVICE" ]; then
        echo "Removing kpartx mappings..."
        kpartx -d "$LOOP_DEVICE" 2>/dev/null || true
    fi
    
    # Detach loop device
    if [ -n "$LOOP_DEVICE" ]; then
        echo "Detaching loop device..."
        sudo losetup -d "$LOOP_DEVICE" 2>/dev/null || true
        LOOP_DEVICE=""
    fi
    
    echo "Cleanup complete"
}

#
# Set up trap for cleanup on exit
# Usage: trap_cleanup
#
trap_cleanup() {
    trap cleanup_mounts EXIT INT TERM
    echo "Cleanup trap set"
}

# Export functions for use in other scripts
export -f setup_loop_device
export -f setup_kpartx
export -f mount_partitions
export -f bind_mount_system
export -f setup_qemu_chroot
export -f cleanup_mounts
export -f trap_cleanup
