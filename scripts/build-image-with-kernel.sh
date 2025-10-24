#!/bin/bash
set -euo pipefail

# Orchestrate full image build including kernel install and packaging
# Usage: SUITE=jammy|trixie|popos RECOMPILE_KERNEL=true|false ARCH=arm64 ./scripts/build-image-with-kernel.sh <output-dir>
SUITE="${SUITE:-trixie}"
ARCH="${ARCH:-arm64}"
RECOMPILE_KERNEL="${RECOMPILE_KERNEL:-false}"
OUTDIR="${1:-output}"
TIMESTAMP=$(date +%Y%m%d)
IMAGE_BASENAME="uconsole-cm4-${SUITE}-${TIMESTAMP}"
IMAGE_NAME="${IMAGE_BASENAME}.img"
IMAGE_NAME_XZ="${IMAGE_NAME}.xz"

echo "Suite: $SUITE; ARCH: $ARCH; RECOMPILE_KERNEL: $RECOMPILE_KERNEL; Output: $OUTDIR"

# Step 1: build base rootfs using existing script
SUITE="$SUITE" ARCH="$ARCH" ./scripts/build-image.sh "$OUTDIR"

# Step 2: run unified setup with kernel recompile option
SUITE="$SUITE" RECOMPILE_KERNEL="$RECOMPILE_KERNEL" ./scripts/setup-suite.sh "$OUTDIR"

# Step 3: If kernel was recompiled, collect .debs from chroot
if [ "$RECOMPILE_KERNEL" = "true" ]; then
  mkdir -p "$OUTDIR/release-artifacts"
  # Note: kernel .debs would have been built inside the chroot at /tmp
  # This is a placeholder for any artifact collection needed
  echo "Kernel was recompiled inside chroot"
fi

# Note: This script collects artifacts and prepares release packaging.
# The actual .img creation step (if using upstream preinstalled images and loop-mount-edit-writeback) can be performed using the legacy create_image.sh flow under scripts/old.

# Produce the source snapshot for release
mkdir -p "$OUTDIR/release-assets/$TIMESTAMP"
git archive --format=tar.gz -o "$OUTDIR/release-assets/$TIMESTAMP/uConsole-Image-Builder-src-${TIMESTAMP}.tar.gz" HEAD || true

# Copy any artifacts into release-assets
cp -a "$OUTDIR/release-artifacts/"* "$OUTDIR/release-assets/$TIMESTAMP/" 2>/dev/null || true

echo "Collected artifacts into $OUTDIR/release-assets/$TIMESTAMP"
echo "If you used the legacy image assembly to produce an .img, put it at $OUTDIR and run scripts/create_release_assets.sh to finalize packaging."
