# Implementation Summary

## Overview

This implementation provides a unified build system for creating bootable uConsole images with the ClockworkPi kernel, using the rpi-image-gen tool and automated CI/CD workflows.

## Key Features

### Simplified Workflow Architecture

**Single Unified Workflow** (`.github/workflows/build-and-release.yml`):
- Replaces 5 separate workflows with one comprehensive workflow
- Builds complete bootable images for multiple distributions (jammy, bookworm, trixie)
- Supports two kernel modes:
  - **prebuilt**: Fast installation using ClockworkPi repository packages
  - **build**: Custom kernel compilation from source with patches
- Automatically creates GitHub releases with all artifacts
- Manual dispatch for on-demand builds with configurable options

### Image Generation

Uses rpi-image-gen (Raspberry Pi's official image generator) to create bootable images:
- Generates complete .img.xz files ready for SD card flashing
- Integrates with ClockworkPi kernel installation
- Supports multiple Debian/Ubuntu distributions
- Creates compressed images with SHA256 checksums

### Kernel Options

**Option 1: Prebuilt Kernel** (Recommended - Fast)
- Uses packages from [clockworkpi/apt](https://github.com/clockworkpi/apt) repository
- Installs: `uconsole-kernel-cm4-rpi`, `clockworkpi-audio`, `clockworkpi-cm-firmware`
- Script: `scripts/install_clockworkpi_kernel.sh`

**Option 2: Build from Source** (Customizable - Slow)
- Builds kernel from [raspberrypi/linux](https://github.com/raspberrypi/linux) @ rpi-6.12.y
- Optionally applies ak-rex patch from `patches/ak-rex.patch`
- Creates .deb packages for distribution
- Script: `scripts/build_clockworkpi_kernel.sh`
- Build time: 2-4 hours on standard hardware

## Files Overview

### Core Scripts

1. **scripts/generate_rpi_image.sh**
   - Main wrapper for rpi-image-gen
   - Creates bootable Raspberry Pi images for uConsole
   - Supports multiple distributions (Debian/Ubuntu)
   - Handles kernel installation (prebuilt or build from source)
   - Generates compressed .img.xz files

2. **scripts/build_clockworkpi_kernel.sh**
   - Builds ClockworkPi kernel from source
   - Clones Raspberry Pi kernel repository
   - Applies patches (ak-rex.patch)
   - Creates Debian .deb packages
   - Outputs to `artifacts/kernel-debs/`

3. **scripts/install_clockworkpi_kernel.sh**
   - Installs prebuilt ClockworkPi kernel packages
   - Configures ClockworkPi apt repository
   - Installs uconsole-kernel-cm4-rpi and related packages
   - Fast alternative to building from source

4. **scripts/common_mounts.sh**
   - Helper functions for loop device management
   - Partition mounting/unmounting utilities
   - Chroot environment setup
   - Safe cleanup with trap handlers

### GitHub Actions Workflow

1. **.github/workflows/build-and-release.yml**
   - Unified workflow for building and releasing uConsole images
   - Three jobs:
     - **build-kernel**: Builds kernel .deb packages from source (when kernel_mode=build)
     - **build-images**: Creates bootable images for selected distributions
     - **create-release**: Publishes GitHub releases with all artifacts
   - Triggers: Git tags (v*, release-*) or manual dispatch
   - Supports configurable options via workflow_dispatch:
     - Distribution suite selection (all, jammy, bookworm, trixie, etc.)
     - Kernel mode (prebuilt or build)
     - Create release toggle

## Default Configuration

- **Default Suite**: jammy (Ubuntu 22.04)
- **Default Architecture**: arm64
- **Default User**: uconsole (password: uconsole)
- **Default Kernel Mode**: prebuilt (fast)
- **Sudo**: Passwordless sudo enabled for uconsole user
- **Compression**: xz (maximum compression)

## Build Process

### Using rpi-image-gen (Recommended)

For complete bootable images:

```bash
# Build with prebuilt kernel (fast)
sudo SUITE=jammy KERNEL_MODE=prebuilt ./scripts/generate_rpi_image.sh

# Build with custom kernel from source (slow)
sudo SUITE=bookworm KERNEL_MODE=build ./scripts/generate_rpi_image.sh

# Build all supported distributions
sudo SUITE=all KERNEL_MODE=prebuilt ./scripts/generate_rpi_image.sh
```

### Legacy: Using build-image.sh and setup-suite.sh

For rootfs-only builds (legacy method):

```bash
# Debian trixie with prebuilt kernel
SUITE=trixie RECOMPILE_KERNEL=false ./scripts/build-image.sh output
SUITE=trixie RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output

# Ubuntu jammy with kernel recompilation
SUITE=jammy RECOMPILE_KERNEL=true ./scripts/build-image.sh output
SUITE=jammy RECOMPILE_KERNEL=true ./scripts/setup-suite.sh output
```

## CI/CD Workflow

### Tag Push Events:
1. Workflow automatically triggers on tags starting with `v*` or `release-*`
2. Builds kernel .deb packages from source
3. Creates bootable images for jammy, bookworm, and trixie
4. Creates GitHub release with all artifacts attached

### Manual Workflow Dispatch:
1. User selects distribution suite (all, jammy, bookworm, trixie, etc.)
2. User selects kernel mode (prebuilt or build)
3. User optionally enables "Create release"
4. Workflow builds selected images
5. If "Create release" enabled, publishes GitHub release

## Workflow Simplification Details

### Previous Structure (5 workflows):
- `build-and-release.yml` - Built rootfs tarballs only
- `build-distro.yaml` - Daily rootfs builds with tagging
- `build-image.yml` - Reusable workflow (unused)
- `image-build.yml` - On-demand image generation
- `release.yml` - Release creation with artifacts

### New Structure (1 workflow):
- `build-and-release.yml` - Unified workflow that:
  - Builds complete bootable images (not just rootfs)
  - Builds kernel packages from source (when requested)
  - Creates GitHub releases with all artifacts
  - Supports flexible manual dispatch options
  - Eliminates redundancy and overlap

### Benefits:
- Single source of truth for CI/CD
- Consistent artifact naming and structure
- Easier to maintain and understand
- Faster execution with parallel builds
- Clear separation of concerns (kernel build → image build → release)

## Notes

- Kernel compilation adds 2-4 hours to build time
- Prebuilt kernel mode is recommended for faster builds
- Builds are cross-architecture (amd64 host, arm64 target)
- Images are compressed with xz for optimal size
- All artifacts include SHA256 checksums for verification
