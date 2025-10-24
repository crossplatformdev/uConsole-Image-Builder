# uConsole-Image-Builder

A collection of BASH scripts to create images for the uConsole CM4.

## Supported Distributions

- **Debian 13 (trixie)** - Default
- **Debian 12 (bookworm)**
- **Ubuntu 22.04 (jammy)**
- **Pop!_OS 22.04** - ARM64 for Raspberry Pi 4

## Quick Start

### Using the unified build scripts (recommended):

The build process uses two environment variables:
- `SUITE`: Distribution to build (`jammy`, `trixie`, `bookworm`, or `popos`)
- `RECOMPILE_KERNEL`: Whether to build kernel from source (`true`/`false`, default: `false`)

Build a Debian trixie rootfs with prebuilt kernel:
```bash
SUITE=trixie RECOMPILE_KERNEL=false ./scripts/build-image.sh output
SUITE=trixie RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output
```

Build a Debian bookworm rootfs with prebuilt kernel:
```bash
SUITE=bookworm RECOMPILE_KERNEL=false ./scripts/build-image.sh output
SUITE=bookworm RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output
```

Build an Ubuntu jammy rootfs and compile kernel from source:
```bash
SUITE=jammy RECOMPILE_KERNEL=true ./scripts/build-image.sh output
SUITE=jammy RECOMPILE_KERNEL=true ./scripts/setup-suite.sh output
```

Build Pop!_OS with prebuilt kernel:
```bash
SUITE=popos RECOMPILE_KERNEL=false ./scripts/build-image.sh output
SUITE=popos RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output
```

Build Pop!_OS with custom image:
```bash
SUITE=popos IMAGE_NAME=custom-popos.img.xz IMAGE_LINK=https://example.com/custom-popos.img.xz RECOMPILE_KERNEL=false ./scripts/build-image.sh output
SUITE=popos RECOMPILE_KERNEL=false ./scripts/setup-suite.sh output
```

Alternative invocation with positional arguments:
```bash
# setup-suite.sh <output-dir> <suite> <recompile_kernel>
./scripts/setup-suite.sh output trixie true
```

See [scripts/README.md](scripts/README.md) for detailed documentation.

### Using the original all-in-one script:

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

## CI/CD

This repository includes automated GitHub Actions workflows that build and publish uConsole images daily.

### Automated Daily Builds

A unified workflow builds rootfs images for all distributions:
- **Pop!_OS 22.04** (based on Ubuntu 22.04 jammy) - tagged as `popos-YYYYMMDD`
- **Debian 13 (trixie)** - tagged as `trixie-YYYYMMDD`
- **Debian 12 (bookworm)** - tagged as `bookworm-YYYYMMDD`
- **Ubuntu 22.04 (jammy)** - tagged as `jammy-YYYYMMDD`

Builds run automatically:
- **Daily at 02:00 UTC** via scheduled cron (builds all distributions)
- **On push to main** when relevant scripts or workflows change (builds all distributions)
- **Manually** via workflow_dispatch (builds selected distribution)

### Environment Variables

The unified build system supports the following environment variables:

- **SUITE**: Distribution to build (`jammy`, `trixie`, `bookworm`, or `popos`)
- **RECOMPILE_KERNEL**: Kernel build mode
  - `true`: Clone and build kernel from `crossplatformdev/linux@rpi-6.12.y` using `fakeroot make -j$(nproc) deb-pkg LOCALVERSION="-raspi"`
  - `false`: Use prebuilt kernel/image from `crossplatformdev/uconsole-ubuntu-apt` repository (Pop!_OS uses CM4/uConsole image)
- **IMAGE_NAME**: Name of the image file to download (for image-based distributions like Pop!_OS)
  - Default: `pop-os_22.04_arm64_raspi_4.img.xz`
  - The `.xz` extension is automatically removed during extraction to derive the actual image filename
- **IMAGE_LINK**: URL to download the image from (for image-based distributions like Pop!_OS)
  - Default: `https://iso.pop-os.org/22.04/arm64/raspi/4/pop-os_22.04_arm64_raspi_4.img.xz`

### Build Artifacts

Each successful build:
1. Creates a tarball artifact (`uconsole-<distro>-arm64-rootfs.tar.gz`)
2. Uploads the artifact to GitHub Actions (retained for 30 days)
3. Creates a git tag with format `<distro>-YYYYMMDD` (e.g., `popos-20251022`)

### Manual Workflow Triggers

To manually trigger a build:

1. Go to the **Actions** tab in the repository
2. Select **Build Distro Image (Unified)**
3. Click **Run workflow**
4. Select the branch
5. Choose the distribution suite (`jammy`, `trixie`, `bookworm`, or `popos`)
6. Toggle **Recompile kernel from source** (default: off/prebuilt)
7. Click **Run workflow** to start the build

### Downloading Build Artifacts

Build artifacts are available in two ways:

1. **From workflow runs**: Go to Actions → Select a workflow run → Scroll to Artifacts section
2. **From git tags**: Each successful build creates a dated tag (e.g., `jammy-20251022`)

### Workflow Architecture

The unified workflow (`.github/workflows/build-distro.yaml`):
- Accepts `suite` and `recompile_kernel` inputs via workflow_dispatch
- Uses matrix strategy to build all distributions on scheduled/push events
- Sets up QEMU for ARM64 cross-compilation
- Runs debootstrap to create base rootfs
- Applies suite-specific customizations via `scripts/setup-suite.sh`
- Handles kernel compilation or prebuilt image selection based on `RECOMPILE_KERNEL`
- Creates and uploads tarball artifacts
- Tags successful builds with date-stamped tags

## Requirements

- Debian or Ubuntu host system
- Root privileges (sudo)
- For modular scripts: `debootstrap`, `qemu-user-static`, `binfmt-support`
- For original script: Various build dependencies (see `create_image.sh`)

## Default Credentials

- Username: `uconsole`
- Password: `uconsole`
- The user has passwordless sudo enabled

## License

See [LICENSE](LICENSE) for details.
