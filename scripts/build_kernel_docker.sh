#!/bin/bash
#
# build_kernel_docker.sh - Build ClockworkPi kernel using Docker
#
# This script builds the kernel inside a Docker container for a reproducible
# build environment. The output files are identical to building without Docker.
#
# Usage: build_kernel_docker.sh [output_dir]
#
# Environment Variables:
#   KERNEL_REPO - Kernel git repository URL (default: https://github.com/raspberrypi/linux.git)
#   KERNEL_BRANCH - Kernel branch to build (default: rpi-6.12.y)
#   KERNEL_LOCALVERSION - Local version string (default: -raspi)
#   APPLY_PATCH - Whether to apply ak-rex patch (default: true)
#   PATCH_FILE - Path to ak-rex patch file (default: patches/ak-rex.patch)
#   KDEB_CHANGELOG_DIST - Debian changelog distribution (default: stable)
#   DOCKER_IMAGE - Docker image name (default: uconsole-kernel-builder)
#   NO_CACHE - Build Docker image without cache (default: false)
#

set -e

# Configuration
KERNEL_REPO="${KERNEL_REPO:-https://github.com/raspberrypi/linux.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-rpi-6.12.y}"
KERNEL_LOCALVERSION="${KERNEL_LOCALVERSION:--raspi}"
APPLY_PATCH="${APPLY_PATCH:-true}"
KDEB_CHANGELOG_DIST="${KDEB_CHANGELOG_DIST:-stable}"
OUTPUT_DIR="${1:-artifacts/kernel-debs}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_FILE="${PATCH_FILE:-$REPO_ROOT/patches/ak-rex.patch}"
DOCKER_IMAGE="${DOCKER_IMAGE:-uconsole-kernel-builder}"
NO_CACHE="${NO_CACHE:-false}"

echo "================================================"
echo "Building ClockworkPi Kernel with Docker"
echo "================================================"
echo "Repository: $KERNEL_REPO"
echo "Branch: $KERNEL_BRANCH"
echo "Local Version: $KERNEL_LOCALVERSION"
echo "Apply Patch: $APPLY_PATCH"
echo "Changelog Distribution: $KDEB_CHANGELOG_DIST"
echo "Output Directory: $OUTPUT_DIR"
echo "Docker Image: $DOCKER_IMAGE"
echo "================================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH" >&2
    echo "Please install Docker: https://docs.docker.com/get-docker/" >&2
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon is not running" >&2
    echo "Please start Docker and try again" >&2
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)

echo "Output directory: $OUTPUT_DIR"

# Check if linux submodule exists
if [ ! -d "$REPO_ROOT/linux" ] || [ ! -e "$REPO_ROOT/linux/.git" ]; then
    echo "ERROR: Linux submodule not found at $REPO_ROOT/linux"
    echo "Please initialize the submodule: git submodule update --init linux"
    exit 1
fi

echo "Linux submodule found, will mount into container"

# Build Docker image
echo ""
echo "Building Docker image..."
CACHE_FLAG=""
if [ "$NO_CACHE" = "true" ]; then
    CACHE_FLAG="--no-cache"
    echo "Building without cache..."
fi

cd "$REPO_ROOT"
docker build $CACHE_FLAG -t "$DOCKER_IMAGE" -f Dockerfile.kernel-builder .

echo ""
echo "Docker image built successfully: $DOCKER_IMAGE"

# Prepare patch file for container (copy to a temp location if it exists)
CONTAINER_PATCH_PATH="/build/ak-rex.patch"
PATCH_MOUNT=""
if [ -f "$PATCH_FILE" ]; then
    echo "Patch file found, will mount into container"
    PATCH_MOUNT="-v $PATCH_FILE:$CONTAINER_PATCH_PATH:ro"
fi

# Run kernel build in Docker container
echo ""
echo "Starting kernel build in Docker container..."
echo "This may take 1-2 hours depending on your system..."
echo ""

docker run --rm \
    -v "$OUTPUT_DIR:/output" \
    -v "$REPO_ROOT/linux:/build/linux-source:ro" \
    -v "$SCRIPT_DIR/build_kernel_in_container.sh:/build/build_kernel_in_container.sh:ro" \
    $PATCH_MOUNT \
    -e KERNEL_REPO="$KERNEL_REPO" \
    -e KERNEL_BRANCH="$KERNEL_BRANCH" \
    -e KERNEL_LOCALVERSION="$KERNEL_LOCALVERSION" \
    -e APPLY_PATCH="$APPLY_PATCH" \
    -e PATCH_FILE="$CONTAINER_PATCH_PATH" \
    -e KDEB_CHANGELOG_DIST="$KDEB_CHANGELOG_DIST" \
    "$DOCKER_IMAGE" \
    bash /build/build_kernel_in_container.sh

echo ""
echo "================================================"
echo "Docker kernel build complete!"
echo "================================================"
echo "Output directory: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR"/*.deb 2>/dev/null || echo "Warning: No .deb files found in output directory"
echo ""
echo "Done!"

exit 0
