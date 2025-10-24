# uConsole Image Builder Scripts

This directory contains scripts to build Debian and Ubuntu rootfs images for the uConsole CM4.

## Scripts

### build-image.sh

Main build script that creates a base rootfs using debootstrap.

**Usage:**
```bash
SUITE=trixie ARCH=arm64 ./scripts/build-image.sh [output-directory]
```

**Environment Variables:**
- `SUITE`: Distribution suite (default: `trixie`)
  - `trixie` - Debian 13
  - `bookworm` - Debian 12
  - `jammy` - Ubuntu 22.04
- `ARCH`: Target architecture (default: `arm64`)
- First positional argument: Output directory (default: `output`)

**What it does:**
1. Runs debootstrap to create a minimal rootfs
2. Sets up QEMU for cross-architecture support
3. Configures apt sources for the selected distribution
4. Installs minimal base packages
5. Leaves the rootfs ready for customization

### setup-suite.sh

Unified customization script for all supported distributions (jammy, trixie, bookworm, popos).

**Usage:**
```bash
# Using environment variables
SUITE=trixie RECOMPILE_KERNEL=false ./scripts/setup-suite.sh [output-directory]

# Using positional arguments
./scripts/setup-suite.sh [output-directory] [suite] [recompile_kernel]
```

**Environment Variables / Arguments:**
- `SUITE` / arg 2: Distribution to configure (`jammy`, `trixie`, `bookworm`, or `popos`)
- `RECOMPILE_KERNEL` / arg 3: Whether to build kernel from source (`true`/`false`, default: `false`)
- First positional argument: Output directory (default: `output`)

**What it does:**
1. Creates `uconsole` user with sudo privileges
2. Installs distribution-specific packages
3. Configures system for uConsole hardware
4. **If RECOMPILE_KERNEL=true:**
   - Clones `crossplatformdev/linux@rpi-6.12.y`
   - Builds kernel using `fakeroot make -j$(nproc) deb-pkg LOCALVERSION="-raspi"`
   - Installs resulting kernel .deb packages
5. **If RECOMPILE_KERNEL=false:**
   - Configures repository for prebuilt kernel packages
   - For Pop!_OS: uses CM4/uConsole-specific image

## Complete Build Examples

### Building Debian trixie image with prebuilt kernel:
```bash
# Build base rootfs
SUITE=trixie ./scripts/build-image.sh my-build

# Apply trixie customizations with prebuilt kernel
SUITE=trixie RECOMPILE_KERNEL=false ./scripts/setup-suite.sh my-build

# Create tarball
cd my-build
tar -czf uconsole-trixie-arm64.tar.gz rootfs-trixie-arm64
```

### Building Debian bookworm image with prebuilt kernel:
```bash
# Build base rootfs
SUITE=bookworm ./scripts/build-image.sh my-build

# Apply bookworm customizations with prebuilt kernel
SUITE=bookworm RECOMPILE_KERNEL=false ./scripts/setup-suite.sh my-build

# Create tarball
cd my-build
tar -czf uconsole-bookworm-arm64.tar.gz rootfs-bookworm-arm64
```

### Building Ubuntu jammy image with kernel recompilation:
```bash
# Build base rootfs
SUITE=jammy ./scripts/build-image.sh my-build

# Apply jammy customizations and compile kernel
SUITE=jammy RECOMPILE_KERNEL=true ./scripts/setup-suite.sh my-build

# Create tarball
cd my-build
tar -czf uconsole-jammy-arm64.tar.gz rootfs-jammy-arm64
```

### Building Pop!_OS image:
```bash
# Build base rootfs (uses jammy as base)
SUITE=jammy ./scripts/build-image.sh my-build

# Apply Pop!_OS customizations
SUITE=popos RECOMPILE_KERNEL=false ./scripts/setup-suite.sh my-build

# Create tarball
cd my-build
tar -czf uconsole-popos-arm64.tar.gz rootfs-jammy-arm64
```

## Requirements

- Debian or Ubuntu host system
- Root privileges (sudo)
- Packages: `debootstrap`, `qemu-user-static`, `binfmt-support`
- For kernel compilation: Additional build tools (automatically installed when RECOMPILE_KERNEL=true)

## Notes

- Default credentials: username `uconsole`, password `uconsole`
- The user has passwordless sudo enabled
- When RECOMPILE_KERNEL=false, kernel packages can be installed from the configured repository
- When RECOMPILE_KERNEL=true, kernel compilation adds significant build time (1-2 hours)
