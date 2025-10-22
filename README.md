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

This repository includes GitHub Actions workflows that automatically build rootfs artifacts for both Debian trixie and Ubuntu jammy when changes are pushed to the main branch. Built artifacts are available as releases.

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
