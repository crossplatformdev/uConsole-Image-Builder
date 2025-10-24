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

The build process uses the `SUITE` environment variable to select the distribution:
- `SUITE`: Distribution to build (`jammy`, `trixie`, `bookworm`, or `popos`)

All rootfs builds use prebuilt kernels from the ClockworkPi repository. For custom kernel builds, use the Docker-based build script (see Option 3).

Build a Debian trixie rootfs:
```bash
SUITE=trixie ./scripts/build-image.sh output
SUITE=trixie ./scripts/setup-suite.sh output
```

Build a Debian bookworm rootfs:
```bash
SUITE=bookworm ./scripts/build-image.sh output
SUITE=bookworm ./scripts/setup-suite.sh output
```

Build an Ubuntu jammy rootfs:
```bash
SUITE=jammy ./scripts/build-image.sh output
SUITE=jammy ./scripts/setup-suite.sh output
```

Build Pop!_OS:
```bash
SUITE=popos ./scripts/build-image.sh output
SUITE=popos ./scripts/setup-suite.sh output
```

Alternative invocation with positional arguments:
```bash
# setup-suite.sh <output-dir> <suite>
./scripts/setup-suite.sh output trixie
```

See [scripts/README.md](scripts/README.md) for detailed documentation.

### Option 3: Build Kernel Packages Only

Build ClockworkPi kernel .deb packages from source using Docker (provides reproducible, isolated builds):

```bash
# Build kernel packages (outputs to artifacts/kernel-debs/)
./scripts/build_clockworkpi_kernel.sh

# Or specify custom output directory
./scripts/build_clockworkpi_kernel.sh /path/to/output
```

**All kernel builds now use Docker for reproducibility and consistency.**
**See [docs/DOCKER_BUILD.md](docs/DOCKER_BUILD.md) for detailed Docker build documentation.**

The kernel build process:
1. Clones the Raspberry Pi kernel (default: `raspberrypi/linux@rpi-6.12.y`)
2. Applies the ak-rex patch if available (`patches/ak-rex.patch`)
3. Configures for Raspberry Pi CM4 (`bcm2711_defconfig`)
4. Builds Debian .deb packages (kernel image, headers, libc-dev)
5. Outputs packages to `artifacts/kernel-debs/`

**Environment Variables for Kernel Build:**
- `KERNEL_REPO`: Kernel repository URL (default: `https://github.com/raspberrypi/linux.git`)
- `KERNEL_BRANCH`: Branch to build (default: `rpi-6.12.y`)
- `KERNEL_LOCALVERSION`: Version suffix (default: `-raspi`)
- `APPLY_PATCH`: Apply ak-rex patch (`true`/`false`, default: `true`)
- `PATCH_FILE`: Path to patch file (default: `patches/ak-rex.patch`)
- `KDEB_CHANGELOG_DIST`: Debian changelog distribution (default: `stable`)

**Docker Build Benefits (Now Default):**
- **Reproducible**: Same build environment every time
- **Isolated**: No need to install build dependencies on host
- **Clean**: No leftover build artifacts on host system
- **Cross-platform**: Works on any system with Docker

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

This repository includes an automated GitHub Actions workflow that builds and publishes uConsole images.

### Build and Release Workflow

The **Build and Release uConsole Images** workflow (`.github/workflows/build-and-release.yml`) is a unified workflow that:

**Triggers:**
- **Git tags**: Push a tag starting with `v*` or `release-*` to automatically build and create a release
  ```bash
  git tag -a v1.0.0 -m "Release v1.0.0"
  git push origin v1.0.0
  ```
- **Manual dispatch**: Build on-demand via Actions tab with customizable options

**Manual Build Options:**
1. Go to **Actions** → **Build and Release uConsole Images** → **Run workflow**
2. Select distribution suite: `all`, `jammy`, `focal`, `bookworm`, `bullseye`, or `trixie`
3. Choose kernel mode:
   - `prebuilt`: Uses ClockworkPi repository packages (fast)
   - `build`: Builds kernel from source with patches (slow, ~2-4 hours)
4. Enable "Create release" to automatically create a GitHub release

**Workflow Jobs:**

1. **Build Kernel Packages** (when kernel_mode=build):
   - Clones Raspberry Pi kernel source
   - Applies ClockworkPi patches
   - Builds .deb packages for distribution
   - Generates kernel source information (KERNEL_INFO.md)

2. **Build Images**:
   - Creates bootable .img.xz files for each selected SUITE using rpi-image-gen
   - Installs kernel (prebuilt from repo OR custom-built .debs)
   - Generates SHA256 checksums
   - Uploads artifacts (retained for 30 days)

3. **Create Release** (on tag push or manual with create_release=true):
   - Creates GitHub release with tag
   - Attaches all artifacts:
     - Bootable .img.xz files for each distribution
     - Kernel .deb packages
     - Kernel source information
     - SHA256 checksums
   - Includes comprehensive installation instructions

**Release Contents:**
- **Images**: uconsole-{suite}-arm64.img.xz for jammy, bookworm, trixie
- **Kernel packages**: linux-image-*.deb, linux-headers-*.deb, linux-libc-dev-*.deb
- **Documentation**: KERNEL_INFO.md with kernel source details
- **Checksums**: SHA256 for all files

**Example: Create a Release**
```bash
# Tag current commit
git tag -a release-20251024 -m "October 2025 release"
git push origin release-20251024

# Workflow automatically:
# 1. Builds kernel packages from source
# 2. Generates images for jammy, bookworm, and trixie
# 3. Creates GitHub release with all files attached
```

**Example: Test Image Build (Manual)**
```
Actions → Build and Release uConsole Images → Run workflow
  - Suite: jammy
  - Kernel mode: prebuilt
  - Create release: false
```

### Environment Variables

The build system supports these key environment variables:

**Rootfs Building (build-image.sh, setup-suite.sh):**
- **SUITE**: Distribution to build (`jammy`, `trixie`, `bookworm`, or `popos`)
- Always uses prebuilt kernel from ClockworkPi apt repository
- For custom kernels, build separately with `./scripts/build_clockworkpi_kernel.sh` and install manually

**Image Generation (generate_rpi_image.sh):**
- **IMAGE_NAME**: Custom image name (default: `uconsole-{suite}-{arch}`)
- **IMAGE_LINK**: Custom base image URL (optional)
- **SUITE**: Distribution suite (`jammy`|`bookworm`|`bullseye`|`trixie`|`focal`|`buster`|`all`)
- **ARCH**: Target architecture (default: `arm64`)
- **ROOTFS_SIZE**: Root filesystem size in MB (default: `4096`)
- **OUTPUT_DIR**: Output directory (default: `output/images`)
- **KERNEL_MODE**: Kernel mode (`prebuilt`|`build`|`none`)
- **COMPRESS_FORMAT**: Compression (`xz`|`gzip`|`none`)

**Kernel Building (build_clockworkpi_kernel.sh - Docker-based):**
- **KERNEL_REPO**: Repository URL (default: `https://github.com/raspberrypi/linux.git`)
- **KERNEL_BRANCH**: Branch (default: `rpi-6.12.y`)
- **KERNEL_LOCALVERSION**: Version suffix (default: `-raspi`)
- **APPLY_PATCH**: Apply ak-rex patch (default: `true`)
- **PATCH_FILE**: Patch file path (default: `patches/ak-rex.patch`)
- **KDEB_CHANGELOG_DIST**: Debian changelog distribution (default: `stable`)

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
   - Image artifacts: `uconsole-{suite}-image` (contains .img.xz and .sha256)
   - Kernel artifacts: `kernel-debs` (contains .deb packages and KERNEL_INFO.md)
2. **From releases**: Complete images and kernel .debs attached to GitHub releases

### Workflow Architecture

**Build and Release uConsole Images** (`.github/workflows/build-and-release.yml`):
- Unified workflow that handles both image building and releases
- **build-kernel job**: Builds kernel .deb packages from source (when kernel_mode=build)
  - Installs kernel build dependencies
  - Clones and builds Raspberry Pi kernel with ClockworkPi patches
  - Generates kernel source metadata
  - Uploads kernel .deb packages as artifacts
- **build-images job**: Creates bootable images for selected distributions
  - Sets up QEMU for ARM64 cross-compilation
  - Uses rpi-image-gen to create base bootable Raspberry Pi images
  - Installs kernel (prebuilt from ClockworkPi repo OR custom-built .debs)
  - Generates compressed .img.xz files
  - Creates SHA256 checksums
  - Uploads image artifacts
- **create-release job**: Publishes GitHub releases (when triggered by tags or manual dispatch)
  - Downloads all artifacts (images and kernel packages)
  - Creates GitHub release with comprehensive documentation
  - Attaches all artifacts to the release

## rpi-image-gen Integration

This project integrates [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen) as a git submodule for creating bootable Raspberry Pi images.

- **Version**: v2.0.0-rc.1-43-g09b6114 (commit: 09b6114)
- **Location**: `/rpi-image-gen/` (submodule)
- **Documentation**: See `scripts/rpi_image_gen/README.md`

The wrapper script `scripts/generate_rpi_image.sh` provides a simplified interface to rpi-image-gen with ClockworkPi kernel integration.

## Linux Kernel Source Integration

This project embeds the Linux kernel source as a git submodule, eliminating the need to clone it repeatedly during builds.

- **Repository**: [raspberrypi/linux](https://github.com/raspberrypi/linux)
- **Branch**: rpi-6.12.y
- **Location**: `/linux/` (submodule)
- **Type**: Shallow submodule (single branch, minimal history)

**Benefits:**
- **Faster builds**: No need to clone kernel source for each build
- **Consistent source**: All builds use the same kernel version
- **Offline builds**: Build without network access once submodules are initialized
- **Reduced bandwidth**: Shallow clone reduces download size

**Usage:**
The build scripts automatically detect and use the embedded linux submodule when available. If the submodule is not initialized, scripts fall back to cloning from GitHub.

To initialize the linux submodule:
```bash
# Initialize just the linux submodule
git submodule update --init linux

# Or initialize all submodules (recommended)
git submodule update --init --recursive
```

**Note:** The linux submodule is configured as a shallow clone to minimize repository size. If you need full git history, you can convert it to a full clone:
```bash
cd linux
git fetch --unshallow
```

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
├── linux/                       # Submodule: Linux kernel source (rpi-6.12.y)
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
│   └── build-and-release.yml    # Unified build and release workflow
├── CHANGES.md                   # Changelog
└── README.md                    # This file
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
