#!/bin/bash
set -euo pipefail

# Orchestrate full image build including kernel install and packaging
# Usage: sudo SUITE=jammy|trixie|popos ARCH=arm64 ./scripts/build-image-with-kernel.sh <output-dir>
SUITE="${SUITE:-trixie}"
ARCH="${ARCH:-arm64}"
OUTDIR="${1:-output}"
TIMESTAMP=$(date +%Y%m%d)
IMAGE_BASENAME="uconsole-cm4-${SUITE}-${TIMESTAMP}"
IMAGE_NAME="${IMAGE_BASENAME}.img"
IMAGE_NAME_XZ="${IMAGE_NAME}.xz"

echo "Suite: $SUITE; ARCH: $ARCH; Output: $OUTDIR"

# Step 1: build base rootfs using existing script
sudo SUITE="$SUITE" ARCH="$ARCH" ./scripts/build-image.sh "$OUTDIR"

# Step 2: run appropriate setup
if [ "\$SUITE" = "trixie" ]; then
  sudo ./scripts/setup-trixie-chroot.sh "\$OUTDIR"
elif [ "\$SUITE" = "jammy" ]; then
  sudo ./scripts/setup-ubuntu-chroot.sh "\$OUTDIR"
elif [ "\$SUITE" = "popos" ] || [ "\$SUITE" = "pop_os" ]; then
  sudo ./scripts/setup-popos-chroot.sh "\$OUTDIR"
else
  echo "Unknown suite: \$SUITE"
  exit 1
fi

# Step 3: For jammy, build kernel and collect .debs
if [ "\$SUITE" = "jammy" ]; then
  mkdir -p "\$OUTDIR/kernel-build"
  sudo ./scripts/build-kernel-jammy.sh "\$OUTDIR/kernel-build"
  # Copy produced .deb files into a known location
  mkdir -p "\$OUTDIR/release-artifacts"
  find "\$OUTDIR/kernel-build" -maxdepth 2 -type f -name "*.deb" -exec cp {} "\$OUTDIR/release-artifacts/" \; || true
fi

# Note: This script collects artifacts and prepares release packaging.
# The actual .img creation step (if using upstream preinstalled images and loop-mount-edit-writeback) can be performed using the legacy create_image.sh flow under scripts/old.

# Produce the source snapshot for release
mkdir -p "\$OUTDIR/release-assets/$TIMESTAMP"
git archive --format=tar.gz -o "\$OUTDIR/release-assets/$TIMESTAMP/uConsole-Image-Builder-src-${TIMESTAMP}.tar.gz" HEAD || true

# Copy kernel .debs and logs into release-assets
cp -a "\$OUTDIR/release-artifacts/"* "\$OUTDIR/release-assets/$TIMESTAMP/" 2>/dev/null || true
cp -a "\$OUTDIR/kernel-build" "\$OUTDIR/release-assets/$TIMESTAMP/kernel-build" 2>/dev/null || true

echo "Collected artifacts into $OUTDIR/release-assets/$TIMESTAMP"
echo "If you used the legacy image assembly to produce an .img, put it at $OUTDIR and run scripts/create_release_assets.sh to finalize packaging."
