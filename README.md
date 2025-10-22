# uConsole-Image-Builder

A collection of BASH scripts to create images for the uConsole CM4.

## Supported Distributions

- **Debian 13 (trixie)** - Default
- **Ubuntu 22.04 (jammy)**
- **Pop!_OS 22.04** - ARM64 for Raspberry Pi 4

## Quick Start

### Using the new modular scripts (recommended):

Build a Debian trixie rootfs:
```bash
sudo SUITE=trixie ./scripts/build-image.sh output
sudo ./scripts/setup-trixie-chroot.sh output
```

Build an Ubuntu jammy rootfs:
```bash
sudo SUITE=jammy ./scripts/build-image.sh output
sudo ./scripts/setup-ubuntu-chroot.sh output
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

Three separate workflows build rootfs images for:
- **Pop!_OS 22.04** (based on Ubuntu 22.04 jammy) - tagged as `popos-YYYYMMDD`
- **Debian 13 (trixie)** - tagged as `trixie-YYYYMMDD`
- **Ubuntu 22.04 (jammy)** - tagged as `jammy-YYYYMMDD`

Builds run automatically:
- **Daily at 02:00 UTC** via scheduled cron
- **On push to main** when relevant scripts or workflows change
- **Manually** via workflow_dispatch

### Build Artifacts

Each successful build:
1. Creates a tarball artifact (`uconsole-<distro>-arm64-rootfs.tar.gz`)
2. Uploads the artifact to GitHub Actions (retained for 30 days)
3. Creates a git tag with format `<distro>-YYYYMMDD` (e.g., `popos-20251022`)

### Manual Workflow Triggers

To manually trigger a build:

1. Go to the **Actions** tab in the repository
2. Select the workflow you want to run:
   - "Build Pop!_OS Image"
   - "Build Debian Trixie Image" 
   - "Build Ubuntu Jammy Image"
3. Click **Run workflow** and select the branch
4. Click **Run workflow** to start the build

### Downloading Build Artifacts

Build artifacts are available in two ways:

1. **From workflow runs**: Go to Actions → Select a workflow run → Scroll to Artifacts section
2. **From git tags**: Each successful build creates a dated tag (e.g., `jammy-20251022`)

### Workflow Architecture

The CI uses a reusable workflow (`.github/workflows/build-image.yml`) that:
- Sets up QEMU for ARM64 cross-compilation
- Runs debootstrap to create base rootfs
- Applies distro-specific customizations
- Creates and uploads tarball artifacts
- Tags successful builds with date-stamped tags

Individual distro workflows (build-popos.yml, build-trixie.yml, build-jammy.yml) call the reusable workflow with distro-specific parameters.

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
