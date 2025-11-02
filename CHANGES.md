# Changelog

All notable changes to the uConsole Image Builder project will be documented in this file.

## [Unreleased]

### Changed - Separate Releases per Distribution

- **Per-Distro Release Strategy**: Modified CI/CD workflow to create separate GitHub releases for each distribution
  - Each distribution (bookworm, trixie, jammy) now gets its own dedicated release
  - Release job uses matrix strategy to process distributions independently
  - Each release contains ~16 images (8 desktops × 2 cores) instead of all 48 images
  - Reduces disk space requirements from ~14GB to ~5GB per release job
  - Prevents "out of disk space" errors on CI/CD runners with limited storage (14GB available)

**Benefits:**
- **Disk Space Efficiency**: Each release job only downloads images for one distribution
- **Better Organization**: Users can easily find images for their preferred distribution
- **Improved Reliability**: Prevents CI/CD failures due to disk space constraints
- **Clear Naming**: Release titles and tags clearly indicate the distribution
  - Example: `uConsole Images - bookworm - rpi-6.12.y`
  - Tag: `uconsole-rpi-6.12.y-release-20241206-123456-bookworm`

### Changed - Docker-Only Kernel Builds

- **Removed Old Kernel Build Methods**: Simplified kernel building to use only Docker
  - Removed `scripts/build-kernel-jammy.sh` (old jammy-specific build)
  - Removed `scripts/build-image-with-kernel.sh` (old orchestration script)
  - Removed chroot-based kernel compilation from `scripts/setup-suite.sh`
  - `scripts/build_clockworkpi_kernel.sh` now always uses Docker
  - `scripts/setup-suite.sh` now always uses prebuilt kernels from ClockworkPi repository
  
- **Updated Documentation**: All documentation updated to reflect Docker-only approach
  - README.md: Removed RECOMPILE_KERNEL references
  - scripts/README.md: Simplified examples
  - DOCKER_BUILD.md: Updated to reflect Docker as the only method
  - IMPLEMENTATION.md: Updated build process documentation

**Benefits:**
- **Consistency**: All kernel builds produce identical results
- **Reproducibility**: Docker eliminates environment-related build issues
- **Simplicity**: One clear method for kernel compilation
- **Maintenance**: Less code to maintain and test

### Added - Linux Kernel Submodule

- **Linux Kernel Source Embedded**: Added the Linux kernel repository as a git submodule
  - Repository: https://github.com/raspberrypi/linux (branch: rpi-6.12.y)
  - Location: `/linux/` (submodule)
  - Configured as shallow submodule to minimize repository size
  - Docker builds clone fresh kernel source for isolation
  
**Benefits:**
- Faster builds: No repeated kernel source cloning
- Consistent source: All builds use the same kernel version
- Offline builds: Build without network access once submodules are initialized
- Reduced bandwidth: Shallow clone configuration reduces download size

### Changed - Workflow Simplification

- **Unified Build and Release Workflow**: Simplified from 5 separate workflows to 1 comprehensive workflow
  - Removed workflows:
    - `build-and-release.yml` (old version - rootfs only)
    - `build-distro.yaml` (daily rootfs builds with tagging)
    - `build-image.yml` (reusable workflow - unused)
    - `image-build.yml` (on-demand image generation)
    - `release.yml` (old release workflow)
  - New unified workflow: `.github/workflows/build-and-release.yml`
    - Combines functionality of all previous workflows
    - Builds complete bootable images (not just rootfs tarballs)
    - Supports both prebuilt and build-from-source kernel modes
    - Automatically creates GitHub releases with all artifacts
    - Triggers on git tags (`v*`, `release-*`) or manual dispatch
    - Single source of truth for CI/CD

- **Workflow Features**:
  - **build-kernel job**: Builds kernel .deb packages from source (when kernel_mode=build)
    - Creates KERNEL_INFO.md with kernel source details
    - Outputs packages to artifacts/kernel-debs/
  - **build-images job**: Creates bootable images for selected distributions
    - Uses rpi-image-gen for image generation
    - Installs kernel (prebuilt from ClockworkPi repo OR custom-built .debs)
    - Generates compressed .img.xz files with SHA256 checksums
    - Matrix builds for jammy, bookworm, and trixie
  - **create-release job**: Publishes GitHub releases
    - Attaches all images and kernel packages
    - Includes comprehensive installation instructions
    - Only runs on tag push or when manually enabled

- **Updated Documentation**:
  - README.md: Rewritten CI/CD section to reflect unified workflow
  - IMPLEMENTATION.md: Updated with workflow simplification details
  - Project structure documentation updated

### Added - rpi-image-gen Integration

- **rpi-image-gen Submodule**: Added rpi-image-gen (v2.0.0-rc.1-43-g09b6114) as a git submodule for Raspberry Pi image generation
  - Repository: https://github.com/raspberrypi/rpi-image-gen
  - Location: `/rpi-image-gen/`
  - Documentation: `scripts/rpi_image_gen/README.md`

- **Image Generation Scripts**:
  - `scripts/generate_rpi_image.sh`: Main wrapper script for generating bootable Raspberry Pi images
    - Supports multiple SUITE values: buster, bullseye, bookworm, trixie, focal, jammy
    - Supports "all" option to build all suites
    - Configurable via environment variables: IMAGE_NAME, IMAGE_LINK, SUITE, ARCH, ROOTFS_SIZE, OUTPUT_DIR, KERNEL_MODE, COMPRESS_FORMAT
    - Integrates with kernel build and installation workflows
    - Creates compressed .img.xz or .img.gz files
  
  - `scripts/common_mounts.sh`: Helper functions for loop device and partition management
    - Provides functions for losetup, kpartx, mount, and cleanup operations
    - Implements automatic cleanup traps for safe error handling
    - Supports chroot environment setup with bind mounts
  
  - `scripts/install_clockworkpi_kernel.sh`: Install prebuilt ClockworkPi kernel packages
    - Configures ClockworkPi apt repository (https://github.com/clockworkpi/apt)
    - Installs uconsole-kernel-cm4-rpi, clockworkpi-audio, and clockworkpi-cm-firmware packages
    - Handles GPG key setup and repository configuration
  
  - `scripts/build_clockworkpi_kernel.sh`: Build kernel from source with ak-rex patch support
    - Clones Raspberry Pi kernel from configurable repository (default: raspberrypi/linux@rpi-6.12.y)
    - Applies ak-rex patch if available (patches/ak-rex.patch)
    - Builds Debian .deb packages using `bindeb-pkg` target
    - Outputs packages to `artifacts/kernel-debs/`
    - Creates installation instructions

- **Kernel Patch Support**:
  - `patches/ak-rex.patch`: Placeholder and documentation for ClockworkPi uConsole kernel patch
    - Includes instructions for obtaining the actual patch
    - Documents patch sources and application methods
    - Provides TODO checklist for integration

- **GitHub Actions Workflows**:
  - `.github/workflows/image-build.yml`: On-demand and PR-triggered image builds
    - Supports workflow_dispatch for manual builds with configurable options
    - Matrix builds for multiple suites
    - Configurable kernel mode: prebuilt, build, or none
    - Configurable compression: xz, gzip, or none
    - Uploads image and kernel artifacts
  
  - `.github/workflows/release.yml`: Automated release workflow
    - Triggered by version tags (v*, release-*)
    - Builds kernel .deb packages
    - Generates images for jammy, bookworm, and trixie
    - Creates GitHub releases with:
      - Kernel .deb packages attached
      - Compressed image files (.img.xz)
      - SHA256 checksums
      - Comprehensive installation instructions

- **Documentation**:
  - Updated README.md with:
    - IMAGE_NAME and IMAGE_LINK environment variable documentation
    - Step-by-step instructions for building images locally
    - CI/CD workflow usage guide
    - Kernel .deb packaging and release process
  - Added `scripts/rpi_image_gen/README.md` with rpi-image-gen integration details
  - Added CHANGES.md (this file) for tracking project changes

- **Infrastructure**:
  - Created `artifacts/kernel-debs/` directory structure for kernel packages
  - Updated `.gitignore` to exclude build artifacts while preserving directory structure
  - Added .gitkeep file to track artifacts directory

### Changed

- **Updated .gitignore**:
  - Removed `linux/` exclusion to allow linux kernel submodule tracking
  - Continues to exclude `linux-raspi/` and `ClockworkPi-linux/` (alternative kernel sources)
  - Excludes specific kernel .deb files while allowing directory tracking
  - Excludes rpi-image-gen build outputs
  - Excludes temporary mount directories
  - Includes compression format variations (.img.gz)

### Environment Variables

New environment variables for image generation:

- **IMAGE_NAME**: Custom name for generated images (default: uconsole-{suite}-{arch})
- **IMAGE_LINK**: Custom base image URL/link to use
- **SUITE**: Distribution suite (buster|bullseye|bookworm|trixie|focal|jammy|all)
- **ARCH**: Target architecture (default: arm64)
- **ROOTFS_SIZE**: Root filesystem size in MB (default: 4096)
- **OUTPUT_DIR**: Output directory for images (default: output/images)
- **KERNEL_MODE**: Kernel installation mode (prebuilt|build|none, default: prebuilt)
- **COMPRESS_FORMAT**: Compression format (xz|gzip|none, default: xz)

### Developer Notes

- All scripts require root/sudo privileges for mounting operations
- Scripts support running in CI environments with privileged containers
- Cleanup handlers ensure proper unmounting even on script failure
- For local development, see README.md for complete build instructions
- Kernel builds can take 2-4 hours depending on hardware

### Known Limitations

- The ak-rex.patch file is currently a placeholder; obtain actual patch from upstream sources
- rpi-image-gen integration uses debootstrap fallback for Debian/Ubuntu suites
- CI runners require adequate disk space for kernel builds (20GB+ recommended)

## Previous Releases

See git history for details on previous changes.
