# Docker Build Documentation

## Overview

The uConsole Image Builder now supports building the kernel using Docker containers. This provides several benefits:

- **Reproducible builds**: Same build environment every time
- **Isolated environment**: No need to install build dependencies on host
- **Clean builds**: No leftover artifacts on host system
- **Cross-platform**: Works on any system with Docker
- **CI/CD friendly**: Easy integration with GitHub Actions and other CI systems

## Docker vs. Native Build Comparison

### Output Files

Both Docker and native builds produce **identical output files**:

1. **Kernel .deb packages**:
   - `linux-image-*.deb` - Kernel image package
   - `linux-headers-*.deb` - Kernel headers for module compilation
   - `linux-libc-dev-*.deb` - Kernel headers for userspace development

2. **Installation instructions**:
   - `INSTALL.txt` - Instructions for installing the kernel packages

3. **File locations**:
   - Default output: `artifacts/kernel-debs/`
   - Custom output: Specified as first argument to build script

### Build Process Comparison

| Aspect | Native Build | Docker Build |
|--------|--------------|--------------|
| **Dependencies** | Must install on host | Contained in image |
| **Build time** | 1-2 hours | 1-2 hours (same) |
| **Disk space** | Build artifacts on host | Only .deb in output |
| **Cleanup** | Manual cleanup needed | Automatic in container |
| **Reproducibility** | Host-dependent | Consistent |
| **Privileges** | Requires sudo | Docker access only |

## Usage

### Basic Usage

```bash
# Using Docker (recommended)
USE_DOCKER=true ./scripts/build_clockworkpi_kernel.sh

# Using the dedicated Docker script
./scripts/build_kernel_docker.sh

# Native build (traditional method)
sudo ./scripts/build_clockworkpi_kernel.sh
```

### Custom Output Directory

```bash
# Docker build with custom output
USE_DOCKER=true ./scripts/build_clockworkpi_kernel.sh /path/to/output

# Native build with custom output
sudo ./scripts/build_clockworkpi_kernel.sh /path/to/output
```

### Environment Variables

All environment variables work the same way for both build methods:

```bash
# Custom kernel source
KERNEL_REPO=https://github.com/custom/linux.git \
KERNEL_BRANCH=custom-branch \
USE_DOCKER=true \
./scripts/build_clockworkpi_kernel.sh

# Disable patch application
APPLY_PATCH=false \
USE_DOCKER=true \
./scripts/build_clockworkpi_kernel.sh

# Custom version suffix
KERNEL_LOCALVERSION=-custom \
USE_DOCKER=true \
./scripts/build_clockworkpi_kernel.sh
```

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

3. **`build_clockworkpi_kernel.sh`**: Unified entry point
   - Checks `USE_DOCKER` environment variable
   - Delegates to Docker script if enabled
   - Otherwise runs native build

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
USE_DOCKER=true ./scripts/build_clockworkpi_kernel.sh /tmp/test-kernel-docker

# Build kernel natively (for comparison)
sudo ./scripts/build_clockworkpi_kernel.sh /tmp/test-kernel-native

# Compare package names and sizes
ls -lh /tmp/test-kernel-docker/*.deb
ls -lh /tmp/test-kernel-native/*.deb
```

**Note**: This will take 2-4 hours total (1-2 hours per build).

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
          USE_DOCKER=true ./scripts/build_clockworkpi_kernel.sh artifacts/kernel-debs
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
DOCKER_IMAGE=uconsole-kernel-builder-custom \
USE_DOCKER=true \
./scripts/build_clockworkpi_kernel.sh
```

### Rebuild Docker Image

Force rebuild of Docker image without cache:

```bash
NO_CACHE=true \
USE_DOCKER=true \
./scripts/build_clockworkpi_kernel.sh
```

### Debug Container

Run interactive shell in build container:

```bash
docker run --rm -it uconsole-kernel-builder bash
```

## Output File Compatibility

The output files from Docker builds are **100% compatible** with native builds:

1. **Binary Compatibility**: Same cross-compiler toolchain (aarch64-linux-gnu-gcc)
2. **Package Format**: Standard Debian .deb packages
3. **Installation**: Use same `dpkg -i` command
4. **Functionality**: Identical kernel configuration and features

### Verification

To verify output compatibility:

```bash
# Extract package metadata
dpkg-deb --info artifacts/kernel-debs/linux-image-*.deb

# Compare checksums (if building same source)
sha256sum artifacts/kernel-debs/*.deb
```

The only differences in metadata will be:
- Build timestamp
- Build hostname (container ID vs. host)
- Build path (`/build/linux` vs. `/tmp/kernel-build-*/linux`)

These differences do **not** affect the kernel binary or functionality.

## FAQ

**Q: Do Docker builds take longer than native builds?**

A: No, build time is the same (1-2 hours). The first run may be slightly slower due to Docker image building (~3-5 minutes), but subsequent builds reuse the cached image.

**Q: Can I use the same output directory for both Docker and native builds?**

A: Yes, but not simultaneously. The output files are compatible, so you can switch between methods.

**Q: Do I need sudo for Docker builds?**

A: You need Docker access, which may require sudo or being in the docker group. The build itself runs without sudo inside the container.

**Q: Will Docker builds work on ARM systems?**

A: Yes, Docker builds work on ARM64 systems. The cross-compilation tools are still used for consistency.

**Q: Can I build on Windows or macOS?**

A: Yes! Docker builds work on any platform that supports Docker Desktop, including Windows and macOS.

## Conclusion

Docker-based kernel building provides a modern, reproducible approach to building the uConsole kernel. The output files are identical to native builds, ensuring full compatibility while providing better isolation and consistency.

For most users, we recommend using Docker builds:
```bash
USE_DOCKER=true ./scripts/build_clockworkpi_kernel.sh
```

This provides the best balance of convenience, reproducibility, and reliability.
