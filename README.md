# uConsole-Image-Builder CI/CD Workflow

This document explains the automated Continuous Integration and Continuous Deployment (CI/CD) workflow for building uConsole images using GitHub Actions.

## Overview

The uConsole-Image-Builder uses a unified GitHub Actions workflow to automatically build bootable Raspberry Pi images for the ClockworkPi uConsole CM4 device. The workflow is designed to create complete, ready-to-flash images with minimal manual intervention.

## Workflow File

The main CI/CD workflow is defined in: `.github/workflows/build-and-release.yml`

## Workflow Architecture

The workflow consists of three main jobs that run sequentially:

### 1. `prepare-kernel` Job

**Purpose**: Build kernel packages from source (only when `kernel_mode=build`)

**Runner**: `ubuntu-24.04-arm` (ARM64 native runner for faster builds)

**Key Steps**:
1. Checks out repository with submodules (includes Linux kernel source)
2. Downloads uConsole-specific kernel patch from ak-rex's fork
3. Applies the patch to Raspberry Pi kernel (rpi-6.12.y branch)
4. Configures kernel for CM4 (bcm2711_defconfig) or CM5 (bcm2712_defconfig)
5. Builds Debian .deb packages using cross-compilation
6. Uploads artifacts:
   - `kernel-debs`: Contains linux-image, linux-headers, and linux-libc-dev packages
   - `kernel-patch-uconsole`: The patch file used for the build

**Environment Variables**:
- `KERNEL_VERSION`: Kernel branch (default: `rpi-6.12.y`)
- `KERNEL_ARCH`: Target architecture (default: `arm64`)
- `KERNEL_COMMIT`: Specific kernel commit/tag to build
- `UCONSOLE_CORE`: Core model (`cm4` or `cm5`, default: `cm4`)

**Build Time**: ~2-4 hours on standard GitHub runners

### 2. `build-image` Job

**Purpose**: Create bootable images for multiple distributions

**Runner**: `ubuntu-24.04-arm` (ARM64 native runner)

**Dependencies**: Requires `prepare-kernel` job to complete (the job passes through quickly when `kernel_mode=prebuilt`)

**Matrix Strategy**: Builds images in parallel for:
- Debian 12 (bookworm)
- Debian 13 (trixie)
- Ubuntu 22.04 (jammy)

**Key Steps**:
1. **Environment Setup**:
   - Installs QEMU for ARM64 emulation
   - Configures binfmt-support for chroot operations
   - Adds Debian/Ubuntu archive keys

2. **Submodule Initialization**:
   - Checks out repository with `rpi-image-gen` submodule
   - Verifies submodule integrity

3. **Base Image Creation**:
   - For Debian (bookworm/trixie): Uses rpi-image-gen to build minimal base images
   - For Ubuntu (jammy): Downloads official Raspberry Pi server image
   - Modifies rpi-image-gen configs for CM4 compatibility

4. **Image Customization**:
   - Mounts image partitions using loop devices
   - Sets up chroot environment with proper bind mounts
   - Removes existing kernel packages
   - Adds ClockworkPi APT repository
   - Installs kernel (prebuilt or custom-built .debs)
   - Installs distribution-specific task packages
   - Configures system:
     - Creates `clockworkpi` user (password: `clockworkpi`)
     - Sets hostname to `uconsole`
     - Enables SSH by default
     - Configures locale (en_US.UTF-8) and timezone (UTC)
     - Sets keyboard layout to US
   - Writes uConsole-specific `config.txt` for boot firmware
   - Generates initramfs for the kernel
   - Cleans up and unmounts partitions

5. **Image Compression**:
   - Compresses image with xz (high compression)
   - Names output: `uconsole-{distro}-cm4.img.xz`

6. **Artifact Upload**:
   - Uploads compressed image as GitHub Actions artifact

**Environment Variables Used**:
- `KERNEL_MODE`: Controls kernel installation method (`prebuilt` or `build`)
- `UBUNTU_TASKS`: Task packages to install for Ubuntu distributions
- `DEBIAN_TASKS`: Task packages to install for Debian distributions

### 3. `release` Job

**Purpose**: Create GitHub releases with all build artifacts

**Runner**: `ubuntu-24.04` (standard x86_64 runner)

**Dependencies**: Requires both `prepare-kernel` and `build-image` jobs to complete

**Trigger Conditions**:
- Runs only on `main` branch pushes
- Runs on any tag push (tags starting with `v*` or `release-*`)

**Key Steps**:
1. Downloads all artifacts:
   - Kernel .deb packages (if built from source)
   - Kernel patch file (if built from source)
   - All distribution images (trixie, bookworm, jammy)

2. Creates release tag:
   - Auto-generates tag name: `release-YYYYMMDD-HHMMSS`
   - Pushes tag to repository

3. Creates GitHub Release:
   - **With kernel build**: Attaches images, kernel packages, and patch
   - **Without kernel build**: Attaches only images
   - Release title format: `Images for uconsole-{CORE}-{VERSION}-{TAG}`
   - Actual tag name: `release-YYYYMMDD-HHMMSS` (auto-generated)
   - Auto-generates release notes from commit history

**Permissions Required**: `contents: write` for creating releases

## Workflow Triggers

The workflow can be triggered in two ways:

### 1. Automatic Trigger (Push Events)

```yaml
on:
  push:
    branches:
      - '**'
```

The workflow runs on every push to any branch. However, releases are only created for:
- Pushes to the `main` branch
- Pushes of tags

### 2. Manual Trigger (Workflow Dispatch)

```yaml
on:
  workflow_dispatch:
    inputs:
      kernel_mode:
        description: 'Kernel mode (build/prebuilt)'
        required: true
        default: 'prebuilt'
        type: choice
        options:
          - build
          - prebuilt
```

**How to Trigger Manually**:
1. Navigate to: GitHub → Actions → "Build and Release uConsole Images"
2. Click "Run workflow"
3. Select options:
   - **Branch**: Choose which branch to build from
   - **Kernel mode**: 
     - `prebuilt` (default): Fast build using ClockworkPi repository packages (~45 minutes)
     - `build`: Compile kernel from source with patches (~3-4 hours)
4. Click "Run workflow"

## Environment Variables

The workflow uses several environment variables for configuration:

```yaml
env:
  KERNEL_MODE: ${{ github.event.inputs.kernel_mode || 'prebuilt' }}
  KERNEL_VERSION: ${{ github.event.inputs.kernel_version || 'rpi-6.12.y' }}
  KERNEL_ARCH: ${{ github.event.inputs.kernel_arch || 'arm64' }}
  KERNEL_COMMIT: 'rpi-6.12.y_20241206_2'
  UBUNTU_TASKS: 'ubuntu-standard ubuntu-server ubuntu-server-raspi task-laptop network-manager netplan.io wpasupplicant net-tools openssh-client openssh-server rfkill fdisk powertop cpufreq*'
  DEBIAN_TASKS: 'live-task-standard live-task-recommended task-laptop laptop-mode-tools network-manager netplan.io wpasupplicant net-tools openssh-client openssh-server rfkill fdisk powertop cpufreq*'
  UCONSOLE_CORE: "cm4"
```

### Key Variables Explained:

- **KERNEL_MODE**: Determines how the kernel is obtained
  - `prebuilt`: Downloads from ClockworkPi APT repository (fast)
  - `build`: Compiles from source with custom patches (slow but customizable)

- **KERNEL_VERSION**: Raspberry Pi kernel branch to use (e.g., `rpi-6.12.y`)

- **KERNEL_COMMIT**: Specific commit or tag in the kernel repository

- **UCONSOLE_CORE**: Target hardware model
  - `cm4`: Raspberry Pi Compute Module 4 (uses bcm2711_defconfig)
  - `cm5`: Raspberry Pi Compute Module 5 (uses bcm2712_defconfig)

- **UBUNTU_TASKS** / **DEBIAN_TASKS**: Package task lists installed in the images

## Build Artifacts

The workflow produces several artifacts:

### During Build (Retained for 30 days):

1. **kernel-debs** (when kernel_mode=build):
   - `linux-image-*.deb`
   - `linux-headers-*.deb`
   - `linux-libc-dev-*.deb`

2. **kernel-patch-uconsole** (when kernel_mode=build):
   - `uconsole-kernel-patch.diff`

3. **uconsole-{distro}-cm4.img.xz**:
   - Complete bootable images for each distribution
   - Compressed with xz for optimal size

### In Releases (Permanent):

1. Bootable images for all distributions
2. Kernel packages (if built from source)
3. Kernel patch file (if built from source)
4. Auto-generated release notes

## Using the Workflow

### Creating a Release

**Method 1: Tag Push (Recommended)**

```bash
# Create an annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push the tag to trigger the workflow
git push origin v1.0.0
```

The workflow will automatically:
1. Build kernel (mode determined by `KERNEL_MODE` environment variable, defaults to `prebuilt`)
2. Create images for all distributions
3. Create a GitHub release with all artifacts

Note: To build kernel from source on tag pushes, set `KERNEL_MODE=build` in the workflow environment variables.

**Method 2: Manual Dispatch**

1. Go to GitHub Actions → "Build and Release uConsole Images"
2. Click "Run workflow"
3. Select `kernel_mode: build` for custom kernel
4. The workflow will run and create a release on completion

### Testing a Build (No Release)

To test the build process without creating a release:

```bash
# Push to any branch other than main
git checkout -b test-build
git push origin test-build
```

Or use manual dispatch with a non-main branch.

Artifacts will be available for download from the Actions tab for 30 days.

## Downloading Artifacts

### From Workflow Runs:

1. Navigate to: Actions → Select workflow run
2. Scroll to "Artifacts" section
3. Download desired artifacts:
   - `kernel-debs` (kernel packages)
   - `uconsole-trixie-cm4.img.xz` (Debian 13 image)
   - `uconsole-bookworm-cm4.img.xz` (Debian 12 image)
   - `uconsole-jammy-cm4.img.xz` (Ubuntu 22.04 image)

### From Releases:

1. Navigate to: Releases
2. Select desired release
3. Download files from "Assets" section

## Image Installation

Once you have a `.img.xz` file, write it to an SD card:

```bash
# Extract and write in one command
xz -dc uconsole-jammy-cm4.img.xz | sudo dd of=/dev/sdX bs=4M status=progress

# Ensure all writes are complete
sudo sync
```

**Replace `/dev/sdX` with your SD card device.**

## Default Credentials

Images created by the workflow have the following default credentials:

- **Username**: `clockworkpi`
- **Password**: `clockworkpi`
- **Hostname**: `uconsole`
- **SSH**: Enabled by default
- **Sudo**: Passwordless sudo enabled for clockworkpi user

## Kernel Patch Source

The workflow downloads the uConsole-specific kernel patch from:

```
https://github.com/raspberrypi/linux/compare/rpi-6.12.y...ak-rex:ClockworkPi-linux:rpi-6.12.y.diff
```

This patch includes:
- Device tree overlays for uConsole hardware
- Audio remapping drivers
- Display drivers for the uConsole screen
- GPIO mappings for the keyboard and controls

## Resource Requirements

### GitHub Actions Runners:

- **Runner Type**: ubuntu-24.04-arm (ARM64 native)
- **Disk Space**: Minimum 20GB free (40GB+ recommended for kernel builds)
- **Memory**: ~7GB (typical for GitHub hosted runners, verify for ARM64 runners)
- **CPU**: 2+ cores (typical for GitHub hosted runners, ARM64 runners may vary)

### Build Times:

- **Prebuilt kernel mode**: ~30-45 minutes per distribution
- **Build kernel mode**: ~3-4 hours (includes 2-4 hours for kernel compilation)

### Parallel Builds:

The `build-image` job uses a matrix strategy to build all three distributions in parallel, reducing total workflow time.

## Troubleshooting

### Common Issues:

1. **Kernel build fails**: Check that the patch URL is accessible and the patch applies cleanly to the specified kernel version

2. **Image mount failures**: Ensure loop devices are available and not in use

3. **Out of disk space**: Kernel builds require significant space; GitHub runners provide ~75GB, but multiple concurrent builds can exhaust this

4. **Submodule not found**: Ensure `actions/checkout@v4` is configured with `submodules: recursive`

### Logs:

Detailed logs for each step are available in the GitHub Actions interface. Failed jobs will show error messages indicating the specific failure point.

## Advanced Configuration

To modify the workflow behavior:

1. **Change distributions**: Edit the matrix in `build-image` job:
   ```yaml
   strategy:
     matrix:
       distro: [bookworm, trixie, jammy, focal]
   ```

2. **Change kernel source**: Modify the patch URL in `prepare-kernel` job

3. **Add custom packages**: Modify `UBUNTU_TASKS` or `DEBIAN_TASKS` environment variables

4. **Change compression**: Modify the `xz` command in the image compression step

## Related Documentation

- [IMPLEMENTATION.md](IMPLEMENTATION.md) - Detailed implementation overview
- [scripts/README.md](scripts/README.md) - Script documentation
- [docs/DOCKER_BUILD.md](docs/DOCKER_BUILD.md) - Docker build information
- [CHANGES.md](CHANGES.md) - Changelog

## Local Development

For local development and testing, see the scripts in the `scripts/` directory:

- `generate_rpi_image.sh` - Generate images locally
- `build_clockworkpi_kernel.sh` - Build kernel packages locally
- `test_scripts.sh` - Run validation tests

## Contributing

To contribute to the CI/CD workflow:

1. Fork the repository
2. Make changes to `.github/workflows/build-and-release.yml`
3. Test using workflow dispatch on your fork
4. Submit a pull request with a description of changes

## License

See [LICENSE](LICENSE) for details.
