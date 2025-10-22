# uConsole Image Builder Scripts

This directory contains scripts to build Debian and Ubuntu rootfs images for the uConsole CM4.

## Scripts

### build-image.sh

Main build script that creates a base rootfs using debootstrap.

**Usage:**
```bash
sudo SUITE=trixie ARCH=arm64 ./scripts/build-image.sh [output-directory]
```

**Environment Variables:**
- `SUITE`: Distribution suite (default: `trixie`)
  - `trixie` - Debian 13
  - `jammy` - Ubuntu 22.04
- `ARCH`: Target architecture (default: `arm64`)
- First positional argument: Output directory (default: `output`)

**What it does:**
1. Runs debootstrap to create a minimal rootfs
2. Sets up QEMU for cross-architecture support
3. Configures apt sources for the selected distribution
4. Installs minimal base packages
5. Leaves the rootfs ready for customization

### setup-trixie-chroot.sh

Customization script for Debian trixie images.

**Usage:**
```bash
sudo ./scripts/setup-trixie-chroot.sh [output-directory]
```

**What it does:**
1. Creates `uconsole` user with sudo privileges
2. Installs uConsole-recommended packages
3. Configures system for uConsole hardware
4. Leaves kernel installation as a separate step

### setup-ubuntu-chroot.sh

Customization script for Ubuntu 22.04 (jammy) images.

**Usage:**
```bash
sudo ./scripts/setup-ubuntu-chroot.sh [output-directory]
```

**What it does:**
1. Creates `uconsole` user with sudo privileges
2. Installs minimal runtime packages
3. Configures system following the original project style
4. Leaves kernel installation as a separate step

## Complete Build Example

### Building Debian trixie image:
```bash
# Build base rootfs
sudo SUITE=trixie ./scripts/build-image.sh my-build

# Apply trixie customizations
sudo ./scripts/setup-trixie-chroot.sh my-build

# Create tarball
cd my-build
sudo tar -czf uconsole-trixie-arm64.tar.gz rootfs-trixie-arm64
```

### Building Ubuntu jammy image:
```bash
# Build base rootfs
sudo SUITE=jammy ./scripts/build-image.sh my-build

# Apply jammy customizations
sudo ./scripts/setup-ubuntu-chroot.sh my-build

# Create tarball
cd my-build
sudo tar -czf uconsole-jammy-arm64.tar.gz rootfs-jammy-arm64
```

## Requirements

- Debian or Ubuntu host system
- Root privileges (sudo)
- Packages: `debootstrap`, `qemu-user-static`, `binfmt-support`

## Notes

- The scripts create rootfs only - kernel installation is separate
- Default credentials: username `uconsole`, password `uconsole`
- The user has passwordless sudo enabled
- Kernel installation should follow uConsole documentation
