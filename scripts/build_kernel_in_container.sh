#!/bin/bash
#
# build_kernel_in_container.sh - Build kernel inside Docker container
#
# This script is designed to run inside the Docker container and performs
# the actual kernel compilation. It's called by build_kernel_docker.sh.
#
# Environment Variables (passed from host):
#   KERNEL_REPO - Kernel git repository URL
#   KERNEL_BRANCH - Kernel branch to build
#   KERNEL_LOCALVERSION - Local version string
#   APPLY_PATCH - Whether to apply ak-rex patch
#   PATCH_FILE - Path to ak-rex patch file (relative to /build)
#   KDEB_CHANGELOG_DIST - Debian changelog distribution
#

set -e

echo "================================================"
echo "Building Kernel Inside Container"
echo "================================================"
echo "Repository: ${KERNEL_REPO}"
echo "Branch: ${KERNEL_BRANCH}"
echo "Local Version: ${KERNEL_LOCALVERSION}"
echo "Apply Patch: ${APPLY_PATCH}"
echo "Changelog Distribution: ${KDEB_CHANGELOG_DIST:-stable}"
echo "================================================"

# Build directory inside container
cd /build

# Use the mounted linux source
echo "Using mounted linux source..."
if [ ! -d "linux-source" ]; then
    echo "ERROR: Linux source not found at /build/linux-source"
    echo "This should have been mounted by the Docker host script"
    exit 1
fi

# Create a working copy since the mount is read-only
echo "Creating working copy of kernel source..."
if [ -d "linux" ]; then
    echo "Removing existing linux directory..."
    rm -rf linux
fi

# Copy the linux source to a writable location
cp -r linux-source linux
cd linux

# Initialize as a git repository (required for make deb-pkg)
# The kernel build system requires a git repository to create source packages
if [ ! -d .git ]; then
    echo "Initializing git repository for kernel build..."
    git init
    git config user.email "build@uconsole-image-builder"
    git config user.name "uConsole Image Builder"
    git add .
    git commit -m "Initial commit from linux submodule" --quiet
fi

echo "Kernel source ready ($(git describe --always 2>/dev/null || echo 'no git info'))"

# Apply ak-rex patch if enabled
if [ "${APPLY_PATCH}" = "true" ]; then
    echo "Checking for ak-rex patch..."
    
    if [ -f "${PATCH_FILE}" ]; then
        # Check if it's an actual patch or just documentation
        if grep -q "^diff " "${PATCH_FILE}" 2>/dev/null || grep -q "^--- " "${PATCH_FILE}" 2>/dev/null; then
            echo "Applying ak-rex patch: ${PATCH_FILE}"
            
            if patch -p1 < "${PATCH_FILE}"; then
                echo "Patch applied successfully"
            else
                echo "ERROR: Failed to apply ak-rex patch" >&2
                exit 1
            fi
        else
            echo "WARNING: Patch file exists but appears to be documentation only"
            echo "Continuing without patch."
        fi
    else
        echo "WARNING: Patch file not found: ${PATCH_FILE}"
        echo "Continuing without patch."
    fi
fi

# Configure kernel
echo "Configuring kernel..."
make ARCH=arm64 bcm2711_defconfig

# Build kernel .deb packages
echo "Building kernel packages (this will take a while)..."
echo "Using $(nproc) parallel jobs"

# Build using bindeb-pkg target (creates binary .deb packages only)
# Set KDEB_CHANGELOG_DIST to specify the distribution in debian/changelog
make deb-pkg -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION="${KERNEL_LOCALVERSION}" KDEB_CHANGELOG_DIST="${KDEB_CHANGELOG_DIST:-stable}"

# Move .deb files to output directory
echo "Collecting kernel packages..."
cd /build

# Find all .deb files
DEB_COUNT=0
for deb in *.deb; do
    if [ -f "$deb" ]; then
        echo "Found: $deb ($(du -h "$deb" | cut -f1))"
        cp "$deb" /output/
        DEB_COUNT=$((DEB_COUNT + 1))
    fi
done

if [ $DEB_COUNT -eq 0 ]; then
    echo "ERROR: No .deb packages found!" >&2
    exit 1
fi

# Get kernel commit info for installation instructions
cd /build/linux
KERNEL_COMMIT=$(git describe --always)

# Create installation instructions in output directory
cat > /output/INSTALL.txt << EOF
ClockworkPi uConsole Kernel Packages
====================================

Build Information:
- Kernel Repository: ${KERNEL_REPO}
- Branch: ${KERNEL_BRANCH}
- Commit: ${KERNEL_COMMIT}
- Local Version: ${KERNEL_LOCALVERSION}
- Patch Applied: ${APPLY_PATCH}
- Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- Build Method: Docker Container

Package Installation:
--------------------

To install these kernel packages on your uConsole:

1. Copy the .deb files to your uConsole:
   scp *.deb uconsole@your-uconsole-ip:/tmp/

2. On your uConsole, install the packages:
   cd /tmp
   sudo dpkg -i linux-*.deb
   sudo apt-get install -f

3. Reboot to use the new kernel:
   sudo reboot

Packages in this directory:
---------------------------
$(ls -1 /output/*.deb 2>/dev/null | xargs -n1 basename || echo "No packages found")

For more information:
- https://github.com/clockworkpi/uConsole
- https://github.com/clockworkpi/apt
EOF

echo "================================================"
echo "Kernel build complete!"
echo "================================================"
echo "Packages created: $DEB_COUNT"
echo ""
ls -lh /output/*.deb
echo ""
echo "Installation instructions: /output/INSTALL.txt"
echo "Done!"

exit 0
