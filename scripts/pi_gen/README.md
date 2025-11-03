# pi-gen Integration

This directory contains documentation and configuration for the pi-gen integration.

## About pi-gen

pi-gen is the traditional Raspberry Pi image generation tool. We use a fork specifically customized for ClockworkPi uConsole devices.

- **Repository**: https://github.com/ak-rex/ClockworkPi-pi-gen
- **Location**: `/pi-gen/` (git submodule)
- **Type**: Fork of RPI-Distro/pi-gen with ClockworkPi customizations

## How pi-gen Works

pi-gen uses a stage-based build system:

- **stage0**: Bootstrap the base Debian/Raspbian system
- **stage1**: Configure basic system settings
- **stage2**: Lite system with networking and basic tools
- **stage3**: Desktop system (optional)
- **stage4**: Full system with additional software (optional)

Each stage contains numbered subdirectories (00-, 01-, etc.) with:
- `00-run.sh`: Scripts run on the host
- `00-run-chroot.sh`: Scripts run inside the chroot
- `00-packages`: Packages to install
- `00-debconf`: Debconf settings

## uConsole Customizations

For uConsole images, we add custom stages:

1. **stage2/06-uconsole-kernel**: Installs ClockworkPi kernel
2. **stage2/07-uconsole-config**: Configures boot settings for uConsole hardware
3. **stage2/08-desktop-environment**: Installs desktop environment (if requested)

## Updating pi-gen

To update the pi-gen submodule to a newer version:

```bash
cd pi-gen
git fetch origin
git checkout main  # or specific tag/branch
cd ..
git add pi-gen
git commit -m "Update pi-gen to latest version"
```

## Using pi-gen

The wrapper script `scripts/generate_pi_image.sh` provides an easy interface to pi-gen.

### Basic Usage

```bash
# Build Debian Bookworm with prebuilt kernel
sudo SUITE=bookworm ./scripts/generate_pi_image.sh

# Build Debian Trixie with custom kernel
sudo SUITE=trixie KERNEL_MODE=build ./scripts/generate_pi_image.sh

# Build with specific desktop environment
sudo SUITE=bookworm DESKTOP=gnome ./scripts/generate_pi_image.sh
```

### Environment Variables

- `SUITE`: Distribution suite (bookworm, trixie)
- `KERNEL_MODE`: prebuilt, build, or none
- `DESKTOP`: gnome, kde, mate, xfce, lxde, lxqt, cinnamon, gnome-flashback, none
- `UCONSOLE_CORE`: cm4 or cm5
- `COMPRESS_FORMAT`: xz, gz, zip, none

## pi-gen Documentation

For detailed pi-gen documentation, see:

- `/pi-gen/README.md` - Main documentation
- https://github.com/ak-rex/ClockworkPi-pi-gen - GitHub repository
- https://github.com/RPI-Distro/pi-gen - Original pi-gen project

## Differences from rpi-image-gen

The previous `rpi-image-gen` tool used a YAML-based configuration approach. The new `pi-gen` tool uses:

- Stage-based builds instead of config files
- More extensive customization options
- Better integration with Debian/Raspbian ecosystem
- ClockworkPi-specific enhancements already integrated

## Troubleshooting

### Build fails with "debootstrap not found"

Install dependencies:
```bash
sudo apt-get install -y coreutils quilt parted qemu-user-static debootstrap \
  zerofree zip dosfstools e2fsprogs libarchive-tools libcap2-bin grep rsync \
  xz-utils file git curl bc gpg pigz xxd arch-test bmap-tools kmod
```

### Build runs out of space

pi-gen requires significant disk space. Ensure you have at least 20GB free.

### Permission errors

pi-gen needs root permissions for chroot operations. Run with `sudo`.
