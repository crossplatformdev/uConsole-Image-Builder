#!/bin/bash
set -euo pipefail

# Build raspberrypi kernel rpi-6.12.y + ak-rex extra commits, produce .deb packages
# Usage: ./scripts/build-kernel-jammy.sh <build-output-dir>
OUTDIR="${1:-kernel-build-output}"
BRANCH="rpi-6.12.y"
RPI_REMOTE="https://github.com/raspberrypi/linux.git"
AKREX_REMOTE="https://github.com/ak-rex/ClockworkPi-linux.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$OUTDIR"
cd "$OUTDIR"

# Use kernel source from repository submodule if available
if [ ! -d linux ]; then
  if [ -d "$REPO_ROOT/linux" ] && [ -e "$REPO_ROOT/linux/.git" ]; then
    echo "Using kernel source from repository submodule..."
    
    # Use rsync to copy source excluding .git to avoid submodule path issues
    rsync -a --exclude='.git' "$REPO_ROOT/linux/" linux/
    
    echo "Kernel source copied from submodule"
  else
    echo "WARNING: Linux submodule not found, falling back to git clone"
    echo "To use the embedded linux folder, run: git submodule update --init linux"
    git clone --depth 1 --branch "$BRANCH" "$RPI_REMOTE" linux
  fi
fi
cd linux

# Ensure we have the branch
git fetch origin "$BRANCH" --depth=1
git checkout -f "$BRANCH"

# Add ak-rex remote and fetch the ak-rex branch
git remote add ak-rex "$AKREX_REMOTE" 2>/dev/null || true
git fetch ak-rex "$BRANCH" --depth=1 || true

# Create a local topic branch based on raspberrypi rpi-6.12.y
git checkout -B uconsole-rpi-6.12.y origin/"$BRANCH"

# Create and apply ak-rex commits that are not in upstream
echo "Applying ak-rex commits on top of origin/$BRANCH..."
COMMITS=$(git log --reverse --pretty=format:"%H" origin/"$BRANCH"..ak-rex/"$BRANCH" 2>/dev/null || true)
if [ -n "$COMMITS" ]; then
  for c in $COMMITS; do
    git cherry-pick -x "$c" || {
      echo "Cherry-pick failed on commit $c; resolve conflicts manually."
      exit 1
    }
  done
else
  echo "No extra commits from ak-rex detected; continuing with vanilla rpi-6.12.y"
fi

# Prepare cross-build environment for deb packaging
export DEB_BUILD_OPTIONS="nocheck"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CONCURRENCY_LEVEL=$(nproc || echo 4)

# Build Debian packages
make bcm2711_defconfig
make -j${CONCURRENCY_LEVEL} deb-pkg LOCALVERSION=-raspi

# After build, .deb packages are placed in the parent directory
echo "Kernel build finished. Debian packages are available in: $(realpath ..)"
