# uConsole-Image-Builder

A collection of BASH scripts to create images for the uConsole CM4.

## Supported Distributions

- **Debian 13 (trixie)** - Default
- **Debian 12 (bookworm)**
- **Ubuntu 22.04 (jammy)**
- **Pop!_OS 22.04** - ARM64 for Raspberry Pi 4

## Quick Start

### Option 1: Generate Bootable Images (Recommended - New!)

Generate complete bootable Raspberry Pi images with the new image generation workflow:

```bash
# Build a complete bootable image for Ubuntu jammy with prebuilt kernel
sudo SUITE=jammy KERNEL_MODE=prebuilt ./scripts/generate_rpi_image.sh

# Build all supported distributions
sudo SUITE=all KERNEL_MODE=prebuilt ./scripts/generate_rpi_image.sh

# Build with custom kernel from source
sudo SUITE=bookworm KERNEL_MODE=build ./scripts/generate_rpi_image.sh
```

The generated images can be found in `output/images/` and are ready to write to SD cards:
```bash
# Extract and write to SD card (replace /dev/sdX with your SD card device)
xz -dc output/images/uconsole-jammy-arm64.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
```

**New Environment Variables for Image Generation:**
- `IMAGE_NAME`: Custom name for the generated image (default: `uconsole-{suite}-{arch}`)
- `IMAGE_LINK`: Custom base image URL/link to use (optional)
- `SUITE`: Distribution suite (`jammy`, `bookworm`, `bullseye`, `trixie`, `focal`, `buster`, or `all`)
- `ARCH`: Target architecture (default: `arm64`)
- `ROOTFS_SIZE`: Root filesystem size in MB (default: `4096`)
- `OUTPUT_DIR`: Output directory for images (default: `output/images`)
- `KERNEL_MODE`: Kernel mode (`prebuilt`, `build`, or `none`, default: `prebuilt`)
- `COMPRESS_FORMAT`: Compression format (`xz`, `gzip`, or `none`, default: `xz`)

### Option 2: Using the unified build scripts (rootfs only):

The build process uses two environment variables:
- `SUITE`: Distribution to build (`jammy`, `trixie`, `bookworm`, or `popos`)
- `RECOMPILE_KERNEL`: Whether to build kernel from source (`true`/`false`, default: `false`)

Build a Debian trixie rootfs with prebuilt kernel:
```bash
sudo SUITE=trixie RECOMPILE_KERNEL=false ./scripts/build-image.sh output
sudo SUITE=trixie RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output
```

Build a Debian bookworm rootfs with prebuilt kernel:
```bash
sudo SUITE=bookworm RECOMPILE_KERNEL=false ./scripts/build-image.sh output
sudo SUITE=bookworm RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output
```

Build an Ubuntu jammy rootfs and compile kernel from source:
```bash
sudo SUITE=jammy RECOMPILE_KERNEL=true ./scripts/build-image.sh output
sudo SUITE=jammy RECOMPILE_KERNEL=true ./scripts/setup-suite.sh output
```

Build Pop!_OS with prebuilt kernel:
```bash
sudo SUITE=popos RECOMPILE_KERNEL=false ./scripts/build-image.sh output
sudo SUITE=popos RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output
```

Alternative invocation with positional arguments:
```bash
# setup-suite.sh <output-dir> <suite> <recompile_kernel>
sudo ./scripts/setup-suite.sh output trixie true
```

See [scripts/README.md](scripts/README.md) for detailed documentation.

### Option 3: Build Kernel Packages Only

Build ClockworkPi kernel .deb packages from source:

```bash
# Build kernel packages (outputs to artifacts/kernel-debs/)
sudo ./scripts/build_clockworkpi_kernel.sh

# Or specify custom output directory
sudo ./scripts/build_clockworkpi_kernel.sh /path/to/output
```

The kernel build process:
1. Clones the Raspberry Pi kernel (default: `raspberrypi/linux@rpi-6.12.y`)
2. Applies the ak-rex patch if available (`patches/ak-rex.patch`)
3. Configures for Raspberry Pi CM4 (`bcm2711_defconfig`)
4. Builds Debian .deb packages (kernel image, headers, libc-dev)
5. Outputs packages to `artifacts/kernel-debs/`

**Environment Variables for Kernel Build:**
- `KERNEL_REPO`: Kernel repository URL (default: `https://github.com/raspberrypi/linux.git`)
- `KERNEL_BRANCH`: Branch to build (default: `rpi-6.12.y`)
- `KERNEL_LOCALVERSION`: Version suffix (default: `-uconsole`)
- `APPLY_PATCH`: Apply ak-rex patch (`true`/`false`, default: `true`)
- `PATCH_FILE`: Path to patch file (default: `patches/ak-rex.patch`)

To install kernel packages on an existing system:
```bash
# Copy .deb files to target device
scp artifacts/kernel-debs/*.deb uconsole@your-device:/tmp/

# Install on target
ssh uconsole@your-device
cd /tmp
sudo dpkg -i linux-*.deb
sudo apt-get install -f
sudo reboot
```

### Option 4: Using the original all-in-one script:

```bash
(as root)# ./create_image.sh
```

The original script will:
1. Create the `.deb` package for GPIO related scripts and services
2. Compile the `@ak-rex` kernel with drivers for uConsole CM4
3. Download and prepare an Ubuntu 22.04 image
4. Install the kernel and GPIO packages

The script takes around 2h30m to complete on a CM4. After it finishes, you will
find a `.xz` compressed image whose name starts with `uConsole-`.

## Building Images Locally - Developer Guide

### Prerequisites

Install required packages on your build machine (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install -y \
  debootstrap \
  qemu-user-static \
  binfmt-support \
  kpartx \
  parted \
  dosfstools \
  rsync \
  xz-utils \
  git
```

For kernel compilation, additionally install:
```bash
sudo apt-get install -y \
  build-essential \
  bc \
  bison \
  flex \
  libssl-dev \
  libncurses-dev \
  libelf-dev \
  fakeroot \
  dpkg-dev
```

### Step-by-Step Local Build

1. **Clone the repository with submodules:**
   ```bash
   git clone --recursive https://github.com/crossplatformdev/uConsole-Image-Builder.git
   cd uConsole-Image-Builder
   ```

2. **Build a complete image:**
   ```bash
   # For Ubuntu jammy with prebuilt kernel
   sudo SUITE=jammy KERNEL_MODE=prebuilt ./scripts/generate_rpi_image.sh
   
   # For Debian bookworm with kernel built from source
   sudo SUITE=bookworm KERNEL_MODE=build ./scripts/generate_rpi_image.sh
   ```

3. **Find your image:**
   ```bash
   ls -lh output/images/
   # Output: uconsole-jammy-arm64.img.xz
   ```

4. **Write to SD card:**
   ```bash
   # Replace /dev/sdX with your SD card device
   xz -dc output/images/uconsole-jammy-arm64.img.xz | \
     sudo dd of=/dev/sdX bs=4M status=progress
   sudo sync
   ```

### Kernel .deb Packages in Releases

Every tagged release includes pre-built kernel .deb packages that can be installed on any compatible system:

1. Download kernel packages from the [Releases](https://github.com/crossplatformdev/uConsole-Image-Builder/releases) page
2. Copy to your uConsole device
3. Install with `dpkg -i` as shown above

This allows you to update just the kernel without reflashing the entire image.

## CI/CD

This repository includes automated GitHub Actions workflows that build and publish uConsole images.

### Image Build Workflow (New!)

The **Build uConsole Images** workflow (`.github/workflows/image-build.yml`) creates complete bootable images:

**Triggers:**
- **Manual dispatch**: Build on-demand via Actions tab
- **Pull requests**: Automatically test image generation when relevant files change

**Manual Build Options:**
1. Go to **Actions** → **Build uConsole Images** → **Run workflow**
2. Select distribution suite: `jammy`, `focal`, `bookworm`, `bullseye`, `trixie`, or `all`
3. Choose kernel mode: `prebuilt`, `build`, or `none`
4. Choose compression: `xz`, `gzip`, or `none`

**Outputs:**
- Complete bootable .img.xz files (or .img.gz)
- SHA256 checksums
- Kernel .deb packages (if kernel_mode=build)
- Artifacts retained for 30 days

**Supported Suites:**
- Ubuntu: jammy (22.04), focal (20.04)
- Debian: bookworm (12), bullseye (11), trixie (13/testing)

### Release Workflow (New!)

The **Release uConsole Images** workflow (`.github/workflows/release.yml`) creates GitHub releases with attached artifacts:

**Triggers:**
- **Git tags**: Push a tag starting with `v*` or `release-*`
  ```bash
  git tag -a v1.0.0 -m "Release v1.0.0"
  git push origin v1.0.0
  ```
- **Manual dispatch**: Create a release on-demand

**Release Contents:**
- Kernel .deb packages (linux-image, linux-headers, linux-libc-dev)
- Bootable images for jammy, bookworm, and trixie (.img.xz)
- SHA256 checksums for all files
- Installation instructions
- Build metadata

**Example Release Process:**
```bash
# Tag current commit
git tag -a release-20251023 -m "October 2025 release"
git push origin release-20251023

# Workflow will automatically:
# 1. Build kernel packages from source
# 2. Generate images for 3 distributions
# 3. Create GitHub release with all files attached
```

### Automated Daily Builds (Rootfs)

The legacy **Build Distro Image (Unified)** workflow continues to build rootfs tarballs:
- **Pop!_OS 22.04** (based on Ubuntu 22.04 jammy) - tagged as `popos-YYYYMMDD`
- **Debian 13 (trixie)** - tagged as `trixie-YYYYMMDD`
- **Debian 12 (bookworm)** - tagged as `bookworm-YYYYMMDD`
- **Ubuntu 22.04 (jammy)** - tagged as `jammy-YYYYMMDD`

Builds run automatically:
- **Daily at 02:00 UTC** via scheduled cron (builds all distributions)
- **On push to main** when relevant scripts or workflows change (builds all distributions)
- **Manually** via workflow_dispatch (builds selected distribution)

### Environment Variables

The build system supports these key environment variables:

**Rootfs Building (build-image.sh, setup-suite.sh):**
- **SUITE**: Distribution to build (`jammy`, `trixie`, `bookworm`, or `popos`)
- **RECOMPILE_KERNEL**: Kernel build mode
  - `true`: Clone and build kernel from `crossplatformdev/linux@rpi-6.12.y`
  - `false`: Use prebuilt kernel from ClockworkPi apt repository

**Image Generation (generate_rpi_image.sh):**
- **IMAGE_NAME**: Custom image name (default: `uconsole-{suite}-{arch}`)
- **IMAGE_LINK**: Custom base image URL (optional)
- **SUITE**: Distribution suite (`jammy`|`bookworm`|`bullseye`|`trixie`|`focal`|`buster`|`all`)
- **ARCH**: Target architecture (default: `arm64`)
- **ROOTFS_SIZE**: Root filesystem size in MB (default: `4096`)
- **OUTPUT_DIR**: Output directory (default: `output/images`)
- **KERNEL_MODE**: Kernel mode (`prebuilt`|`build`|`none`)
- **COMPRESS_FORMAT**: Compression (`xz`|`gzip`|`none`)

**Kernel Building (build_clockworkpi_kernel.sh):**
- **KERNEL_REPO**: Repository URL (default: `https://github.com/raspberrypi/linux.git`)
- **KERNEL_BRANCH**: Branch (default: `rpi-6.12.y`)
- **KERNEL_LOCALVERSION**: Version suffix (default: `-uconsole`)
- **APPLY_PATCH**: Apply ak-rex patch (default: `true`)
- **PATCH_FILE**: Patch file path (default: `patches/ak-rex.patch`)

### Build Artifacts

**Daily rootfs builds:**
1. Creates a tarball artifact (`uconsole-<distro>-arm64-rootfs.tar.gz`)
2. Uploads the artifact to GitHub Actions (retained for 30 days)
3. Creates a git tag with format `<distro>-YYYYMMDD` (e.g., `popos-20251022`)

**Image builds:**
1. Complete bootable images (`uconsole-<distro>-<arch>.img.xz`)
2. SHA256 checksums
3. Kernel .deb packages (when built from source)

**Releases:**
1. Kernel .deb packages attached to GitHub Release
2. Bootable images for multiple distributions
3. Checksums and installation instructions

### CI Runner Requirements

**For image builds:**
- Requires `sudo` access for mounting loop devices
- Minimum 20GB free disk space (more for kernel builds)
- Standard GitHub-hosted runners work with QEMU for cross-compilation

**For kernel builds:**
- 2-4 hours build time on standard runners
- Requires kernel build tools (automatically installed by workflow)
- Uses `fakeroot` and cross-compilation when needed

### Manual Workflow Triggers

**Build Distro Image (Unified):**
1. Go to the **Actions** tab in the repository
2. Select **Build Distro Image (Unified)**
3. Click **Run workflow**
4. Select the branch
5. Choose the distribution suite (`jammy`, `trixie`, `bookworm`, or `popos`)
6. Toggle **Recompile kernel from source** (default: off/prebuilt)
7. Click **Run workflow** to start the build

### Downloading Build Artifacts

Build artifacts are available in multiple ways:

1. **From workflow runs**: Go to Actions → Select a workflow run → Scroll to Artifacts section
2. **From git tags**: Rootfs builds create dated tags (e.g., `jammy-20251022`)
3. **From releases**: Kernel .debs and complete images attached to tagged releases

### Workflow Architecture

**Build Distro Image (Unified)** (`.github/workflows/build-distro.yaml`):
- Accepts `suite` and `recompile_kernel` inputs via workflow_dispatch
- Uses matrix strategy to build all distributions on scheduled/push events
- Sets up QEMU for ARM64 cross-compilation
- Runs debootstrap to create base rootfs
- Applies suite-specific customizations via `scripts/setup-suite.sh`
- Handles kernel compilation or prebuilt image selection based on `RECOMPILE_KERNEL`
- Creates and uploads tarball artifacts
- Tags successful builds with date-stamped tags

**Build uConsole Images** (`.github/workflows/image-build.yml`):
- On-demand or PR-triggered complete image generation
- Matrix builds for multiple suites
- Generates bootable .img.xz files
- Optional kernel compilation from source
- Uploads images and kernel .debs as artifacts

**Release uConsole Images** (`.github/workflows/release.yml`):
- Triggered by version tags or manual dispatch
- Builds kernel packages from source
- Generates images for key distributions
- Creates GitHub releases with all artifacts attached
- Includes comprehensive installation instructions

## rpi-image-gen Integration

This project integrates [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen) as a git submodule for creating bootable Raspberry Pi images.

- **Version**: v2.0.0-rc.1-43-g09b6114 (commit: 09b6114)
- **Location**: `/rpi-image-gen/` (submodule)
- **Documentation**: See `scripts/rpi_image_gen/README.md`

The wrapper script `scripts/generate_rpi_image.sh` provides a simplified interface to rpi-image-gen with ClockworkPi kernel integration.

### ClockworkPi Kernel Integration

Two modes are supported for kernel installation:

**1. Prebuilt Kernel (Recommended - Fast)**
- Uses packages from [clockworkpi/apt](https://github.com/clockworkpi/apt)
- Installs: `uconsole-kernel-cm4-rpi`, `clockworkpi-audio`, `clockworkpi-cm-firmware`
- Script: `scripts/install_clockworkpi_kernel.sh`

**2. Build from Source (Customizable - Slow)**
- Builds kernel from [raspberrypi/linux](https://github.com/raspberrypi/linux) @ rpi-6.12.y
- Optionally applies ak-rex patch from `patches/ak-rex.patch`
- Creates .deb packages for distribution
- Script: `scripts/build_clockworkpi_kernel.sh`
- Build time: 2-4 hours on standard hardware

### About the ak-rex Patch

The `patches/ak-rex.patch` file currently contains documentation about obtaining the actual patch. The patch adds ClockworkPi uConsole device support to the Raspberry Pi kernel, including:
- Device tree overlays
- Audio remapping
- Display drivers
- GPIO mappings

To use the patch:
1. Obtain the actual patch from ClockworkPi sources or community forks
2. Place it in `patches/ak-rex.patch`
3. Build kernel with `APPLY_PATCH=true`

## Requirements

**For building images locally:**
- Debian or Ubuntu host system
- Root privileges (sudo)
- Required packages:
  - `debootstrap`, `qemu-user-static`, `binfmt-support`
  - `kpartx`, `parted`, `dosfstools`
  - `rsync`, `xz-utils`, `git`

**For kernel compilation:**
- Additional packages:
  - `build-essential`, `bc`, `bison`, `flex`
  - `libssl-dev`, `libncurses-dev`, `libelf-dev`
  - `fakeroot`, `dpkg-dev`, `debhelper`

**For CI builds:**
- GitHub Actions runner with sudo access
- Minimum 20GB free disk space
- 2-4 hours for kernel builds

## Default Credentials

- Username: `uconsole`
- Password: `uconsole`
- The user has passwordless sudo enabled

## Project Structure

```
uConsole-Image-Builder/
├── rpi-image-gen/              # Submodule: Raspberry Pi image generator
├── scripts/
│   ├── generate_rpi_image.sh   # Main image generation wrapper
│   ├── common_mounts.sh        # Loop device and mount helpers
│   ├── build_clockworkpi_kernel.sh  # Build kernel from source
│   ├── install_clockworkpi_kernel.sh  # Install prebuilt kernel
│   ├── build-image.sh          # Create base rootfs
│   ├── setup-suite.sh          # Suite-specific customizations
│   └── rpi_image_gen/
│       └── README.md           # rpi-image-gen documentation
├── patches/
│   └── ak-rex.patch            # ClockworkPi kernel patch (placeholder)
├── artifacts/
│   └── kernel-debs/            # Kernel .deb packages output directory
├── .github/workflows/
│   ├── image-build.yml         # Image generation workflow
│   ├── release.yml             # Release with kernel .debs
│   └── build-distro.yaml       # Daily rootfs builds
├── CHANGES.md                  # Changelog
└── README.md                   # This file
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request

For kernel patches or distribution-specific issues, please provide:
- Distribution and version
- Kernel version
- Steps to reproduce
- Expected vs actual behavior

## Related Projects

- [ClockworkPi uConsole](https://github.com/clockworkpi/uConsole) - Official uConsole repository
- [ClockworkPi apt](https://github.com/clockworkpi/apt) - Prebuilt kernel packages
- [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen) - Raspberry Pi image generator
- [Raspberry Pi Linux](https://github.com/raspberrypi/linux) - Official Raspberry Pi kernel

## License

See [LICENSE](LICENSE) for details.
