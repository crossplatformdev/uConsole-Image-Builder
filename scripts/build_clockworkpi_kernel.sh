#!/bin/bash
#
# build_clockworkpi_kernel.sh - Build ClockworkPi kernel using Docker
#
# This script builds Linux kernel .deb packages for ClockworkPi uConsole devices
# using Docker for reproducible builds. It delegates to build_kernel_docker.sh.
#
# Usage: build_clockworkpi_kernel.sh [output_dir]
#
# Environment Variables:
#   KERNEL_REPO - Kernel git repository URL (default: https://github.com/raspberrypi/linux.git)
#   KERNEL_BRANCH - Kernel branch to build (default: rpi-6.12.y)
#   KERNEL_LOCALVERSION - Local version string (default: -raspi)
#   APPLY_PATCH - Whether to apply ak-rex patch (default: true)
#   PATCH_FILE - Path to ak-rex patch file (default: patches/ak-rex.patch)
#   KDEB_CHANGELOG_DIST - Debian changelog distribution (default: stable)
#

set -e

# Always use Docker for kernel builds
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Building kernel using Docker (reproducible builds)"
exec sudo "$SCRIPT_DIR/build_kernel_docker.sh" "$@"
