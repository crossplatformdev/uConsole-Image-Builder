# rpi-image-gen Integration

This directory contains documentation and configuration for the rpi-image-gen integration.

## About rpi-image-gen

rpi-image-gen is the official Raspberry Pi image generation tool from the Raspberry Pi Foundation. It creates highly customizable, reproducible Raspberry Pi OS images.

- **Repository**: https://github.com/raspberrypi/rpi-image-gen
- **Included Version**: v2.0.0-rc.1-43-g09b6114 (commit: 09b6114)
- **Location**: `/rpi-image-gen/` (git submodule)

## Updating rpi-image-gen

To update the rpi-image-gen submodule to a newer version:

```bash
# Navigate to the submodule directory
cd rpi-image-gen

# Fetch latest changes
git fetch origin

# Checkout a specific tag or commit
git checkout v2.0.0  # or any other tag/commit

# Go back to main repository
cd ..

# Commit the submodule update
git add rpi-image-gen
git commit -m "Update rpi-image-gen to v2.0.0"
```

## Using rpi-image-gen

The wrapper script `scripts/generate_rpi_image.sh` provides an easy interface to rpi-image-gen.

See the main README.md for usage examples and environment variable documentation.

## rpi-image-gen Documentation

For detailed rpi-image-gen documentation, see:
- `/rpi-image-gen/README.adoc` - Main documentation
- https://github.com/raspberrypi/rpi-image-gen - GitHub repository

## Supported Features

The wrapper script supports:
- Multiple Debian/Ubuntu suites (buster, bullseye, bookworm, trixie, focal, jammy)
- Custom image names and links
- Configurable root filesystem size
- Custom output directories
- Integration with ClockworkPi kernel packages
