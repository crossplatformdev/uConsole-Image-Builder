# Docker Build Documentation

## Overview

The uConsole Image Builder now supports building the kernel using Docker containers. This provides several benefits:

- **Reproducible builds**: Same build environment every time
- **Isolated environment**: No need to install build dependencies on host
- **Clean builds**: No leftover artifacts on host system
- **Cross-platform**: Works on any system with Docker
- **CI/CD friendly**: Easy integration with GitHub Actions and other CI systems

## Docker Build (Now Default)

**Note:** As of this version, Docker builds are the only supported method for kernel compilation. Native/chroot builds have been removed to ensure consistency and reproducibility.

### Output Files

Docker builds produce the following output files:

1. **Kernel .deb packages**:
   - `linux-image-*.deb` - Kernel image package
   - `linux-headers-*.deb` - Kernel headers for module compilation
   - `linux-libc-dev-*.deb` - Kernel headers for userspace development

2. **Installation instructions**:
   - `INSTALL.txt` - Instructions for installing the kernel packages

3. **File locations**:
   - Default output: `artifacts/kernel-debs/`
   - Custom output: Specified as first argument to build script

### Build Process Features

| Aspect | Docker Build |
|--------|--------------|
| **Dependencies** | All contained in Docker image |
| **Build time** | 1-2 hours |
| **Disk space** | Only .deb files in output directory |
| **Cleanup** | Automatic in container |
| **Reproducibility** | Fully consistent across systems |
| **Privileges** | Docker access only (no sudo needed) |

## Usage

### Basic Usage

```bash
# Build kernel using Docker (now the only method)
./scripts/build_clockworkpi_kernel.sh

# Alternative: use the Docker script directly
./scripts/build_kernel_docker.sh
```

### Custom Output Directory

```bash
# Docker build with custom output
./scripts/build_clockworkpi_kernel.sh /path/to/output
```

### Environment Variables

Customize the kernel build with environment variables:

```bash
# Custom kernel source
KERNEL_REPO=https://github.com/custom/linux.git \
KERNEL_BRANCH=custom-branch \
./scripts/build_clockworkpi_kernel.sh

# Disable patch application
APPLY_PATCH=false \
./scripts/build_clockworkpi_kernel.sh

# Custom version suffix
KERNEL_LOCALVERSION=-custom \
./scripts/build_clockworkpi_kernel.sh

# Set Debian changelog distribution
KDEB_CHANGELOG_DIST=bookworm \
./scripts/build_clockworkpi_kernel.sh
```

**Available Environment Variables:**
- `KERNEL_REPO`: Kernel repository URL (default: `https://github.com/raspberrypi/linux.git`)
- `KERNEL_BRANCH`: Branch to build (default: `rpi-6.12.y`)
- `KERNEL_LOCALVERSION`: Version suffix (default: `-raspi`)
- `APPLY_PATCH`: Apply ak-rex patch (`true`/`false`, default: `true`)
- `PATCH_FILE`: Path to patch file (default: `patches/ak-rex.patch`)
- `KDEB_CHANGELOG_DIST`: Debian changelog distribution (default: `stable`)
- `DOCKER_IMAGE`: Docker image name (default: `uconsole-kernel-builder`)
- `NO_CACHE`: Build Docker image without cache (`true`/`false`, default: `false`)

## Docker Implementation Details

### Dockerfile (`Dockerfile.kernel-builder`)

The Dockerfile creates a build environment based on Ubuntu 22.04 with:
- All kernel build tools (gcc, make, binutils)
- Cross-compilation tools for ARM64 (aarch64-linux-gnu-)
- Debian packaging tools (dpkg-dev, debhelper)
- Version control (git)

### Build Scripts

1. **`build_kernel_docker.sh`**: Main wrapper script
   - Builds Docker image if needed
   - Mounts output directory and scripts
   - Passes environment variables to container
   - Runs build inside container

2. **`build_kernel_in_container.sh`**: Container-side build script
   - Clones kernel source
   - Applies patches
   - Configures and builds kernel
   - Creates .deb packages
   - Copies output to mounted volume

3. **`build_clockworkpi_kernel.sh`**: Main entry point
   - Always uses Docker for builds
   - Delegates to Docker script for all builds

### Volume Mounts

The Docker build uses volume mounts to:
- Mount output directory: `/path/on/host` → `/output` in container
- Mount build script: `scripts/build_kernel_in_container.sh` → `/build/build_kernel_in_container.sh`
- Mount patch file (if exists): `patches/ak-rex.patch` → `/build/ak-rex.patch`

This ensures that output files are written directly to the host filesystem.

## Testing

### Quick Test (No Build)

Test the Docker setup without performing a full kernel build:

```bash
./scripts/test_docker_build.sh
```

This validates:
- Docker is installed and running
- Docker image can be built
- Container can execute commands
- Build tools are available
- Scripts can be mounted
- Environment variables work

### Full Build Test

To verify that Docker builds produce working kernel packages:

```bash
# Build kernel using Docker
./scripts/build_clockworkpi_kernel.sh /tmp/test-kernel

# Verify packages were created
ls -lh /tmp/test-kernel/*.deb
```

**Note**: This will take 1-2 hours.

## GitHub Actions Integration

The CI workflow automatically uses Docker for kernel builds. Here's the relevant workflow excerpt:

```yaml
# .github/workflows/build-and-release.yml
jobs:
  build-kernel:
    name: Build Kernel Packages
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build ClockworkPi kernel using Docker
        run: |
          ./scripts/build_clockworkpi_kernel.sh artifacts/kernel-debs
```

Benefits for CI:
- No need to install build dependencies
- Consistent builds across different runners
- Faster setup (dependencies cached in image)
- Cleaner runner environment

## Troubleshooting

### Docker Not Running

**Error**: `ERROR: Docker daemon is not running`

**Solution**: Start Docker:
```bash
# Linux
sudo systemctl start docker

# macOS/Windows
# Start Docker Desktop application
```

### Permission Issues

**Error**: `permission denied while trying to connect to Docker`

**Solution**: Add user to docker group:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Disk Space

**Error**: Build fails with "no space left on device"

**Requirements**:
- Docker image: ~700 MB
- Kernel source: ~2 GB
- Build artifacts: ~1 GB
- Total: At least 5 GB free space recommended

**Solution**: Clean up Docker:
```bash
docker system prune -a
```

### Slow Builds

**Issue**: Build takes longer than expected

**Optimization**:
1. Use Docker BuildKit: `DOCKER_BUILDKIT=1`
2. Increase Docker resources (CPU/RAM) in Docker Desktop
3. Use local SSD for Docker storage

## Advanced Usage

### Custom Docker Image

Build a custom Docker image with additional tools:

```dockerfile
# Dockerfile.custom
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install standard kernel build tools
RUN apt-get update && apt-get install -y \
    build-essential bc bison flex libssl-dev \
    libncurses-dev libelf-dev kmod cpio rsync git \
    fakeroot dpkg-dev debhelper kernel-wedge wget \
    crossbuild-essential-arm64 ca-certificates \
    your-custom-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
```

Build and use the custom image:

```bash
# Build custom Docker image
docker build -t uconsole-kernel-builder-custom -f Dockerfile.custom .

# Use custom image for kernel build
DOCKER_IMAGE=uconsole-kernel-builder-custom ./scripts/build_clockworkpi_kernel.sh
```

### Rebuild Docker Image

Force rebuild of Docker image without cache:

```bash
NO_CACHE=true ./scripts/build_clockworkpi_kernel.sh
```

### Debug Container

Run interactive shell in build container:

```bash
docker run --rm -it uconsole-kernel-builder bash
```

## Output Files

Docker builds produce standard Debian kernel packages:

1. **Binary Compatibility**: Uses standard cross-compiler toolchain (aarch64-linux-gnu-gcc)
2. **Package Format**: Standard Debian .deb packages
3. **Installation**: Use standard `dpkg -i` command
4. **Functionality**: Full kernel configuration and features for Raspberry Pi CM4

### Verification

To verify output packages:

```bash
# Extract package metadata
dpkg-deb --info artifacts/kernel-debs/linux-image-*.deb

# Verify checksums
sha256sum artifacts/kernel-debs/*.deb
```

Build metadata includes:
- Build timestamp
- Build hostname (Docker container ID)
- Build path (`/build/linux`)
- Kernel version and configuration

## FAQ

**Q: How long does a Docker build take?**

A: Build time is 1-2 hours. The first run may be slightly slower due to Docker image building (~3-5 minutes), but subsequent builds reuse the cached image.

**Q: Do I need sudo for Docker builds?**

A: You need Docker access, which may require sudo or being in the docker group. The build itself runs without sudo inside the container.

**Q: Will Docker builds work on ARM systems?**

A: Yes, Docker builds work on ARM64 systems. The cross-compilation tools are still used for consistency.

**Q: Can I build on Windows or macOS?**

A: Yes! Docker builds work on any platform that supports Docker Desktop, including Windows and macOS.

**Q: Why are native builds no longer supported?**

A: Docker builds provide consistent, reproducible results across all platforms. This eliminates environment-related build issues and ensures that all builds produce identical kernel packages.

## Conclusion

Docker-based kernel building is now the only supported method for building the uConsole kernel. This ensures consistent, reproducible builds across all platforms.

To build a kernel:
```bash
./scripts/build_clockworkpi_kernel.sh
```

This provides the best balance of convenience, reproducibility, and reliability.
