#!/bin/bash


############################################################################################################
# This script is for the ClockworkPi Devterm and uConsole. It will compile a custom kernel                 #
# for the Raspberry Pi Compute Module 4 and install it on an Ubuntu 22.04.5 image.                         #
############################################################################################################

### Instructions ###
# 1. On an Ubuntu or Debian, amd64 or arm64 host machine, download and run this script as sudo.
# 2. The script will download the Ubuntu 22.04.5 image, clone the ak-rex kernel, compile the kernel, and install it on the image.
# 3. Flash the image to a microSD card and insert it into the uConsole.
# 4. Boot the device and enjoy the new kernel.

# Usage: ./create_uconsole_image.sh 

#Create GPIO package
./make_gpio_package.sh

#Compile the kernel
sudo apt build-dep -y linux linux-image-unsigned-6.8.0-49-generic linux-image-unsigned-6.8.0-49-lowlatency
sudo apt install -y libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf \
     curl llvm git qemu-user-static gcc-12 g++-12 qemu-user-static binfmt-support

sudo apt install -y bc bison flex libssl-dev make libc6-dev libncurses5-dev debhelper-compat 
sudo apt install -y crossbuild-essential-arm64

#Clone ak-rex kernel from github
#git clone -b ubuntu/jammy-updates https://git.launchpad.net/ubuntu/+source/linux-raspi
#cd linux-raspi

git clone -b rpi-6.9.y https://github.com/raspberrypi/linux.git
cd linux


wget https://github.com/raspberrypi/linux/compare/rpi-6.6.y...ak-rex:ClockworkPi-linux:rpi-6.6.y.diff
patch -p1 < rpi-6.6.y...ak-rex:ClockworkPi-linux:rpi-6.6.y.diff

#git clone -b rpi-6.6.y https://github.com/ak-rex/ClockworkPi-linux.git
#cd ClockworkPi-linux
git pull


export $(dpkg-architecture -aarm64)
export CROSS_COMPILE=aarch64-linux-gnu-

#chmod a+x debian/rules
#chmod a+x debian/scripts/*
#chmod a+x debian/scripts/misc/*
#fakeroot debian/rules clean
#fakeroot debian/rules editconfigs 
#fakeroot debian/rules binary

KERNEL=kernel8
make bcm2711_defconfig
make -j6 deb-pkg LOCALVERSION=-raspi

cd ..

wget https://cdimage.ubuntu.com/releases/jammy/release/ubuntu-22.04.5-preinstalled-desktop-arm64+raspi.img.xz

#Extract the image
unxz ubuntu-22.04.5-preinstalled-desktop-arm64+raspi.img.xz

#Mount the image
losetup -D
losetup /dev/loop777 -P ubuntu-22.04.5-preinstalled-desktop-arm64+raspi.img

mkdir rootfs
sudo mount /dev/loop777p2 rootfs    
mkdir rootfs/boot/firmware
sudo mount /dev/loop777p1 rootfs/boot/firmware


sudo mount --bind /dev rootfs/dev
sudo mount --bind /dev/pts rootfs/dev/pts
sudo mount --bind /proc rootfs/proc
sudo mount --bind /sys rootfs/sys

mv rootfs/etc/resolv.conf rootfs/etc/resolv.conf.bak
cp /etc/resolv.conf rootfs/etc/resolv.conf

#Copy the .deb files to the image chroot environment and install them
mkdir rootfs/usr/local/src/ClockworkPi-linux
cp linux-headers-6.9.12-v8-raspi_6.9.12-*.deb  rootfs/usr/local/src/ClockworkPi-linux
cp linux-image-6.9.12-v8-raspi_6.9.12-*arm64.deb rootfs/usr/local/src/ClockworkPi-linux
cp linux-libc-dev_6.9.12-*arm64.deb  rootfs/usr/local/src/ClockworkPi-linux
cp linux-raspi-tools-*arm64.deb rootfs/usr/local/src/ClockworkPi-linux
cp uconsole-cm4-gpio.deb rootfs/usr/local/src/ClockworkPi-linux

#cp linux-upstream_1_.orig.tar.xz rootfs/usr/local/src

chroot rootfs /bin/bash -c "apt purge -y --allow-change-held-packages linux-image* linux-headers*"

##Append the following to /etc/apt/sources.list
#echo "#Ubuntu noble main repository, needed for gcc-13" >> rootfs/etc/apt/sources.list
#echo "deb http://ports.ubuntu.com/ubuntu-ports/ noble main restricted" >> rootfs/etc/apt/sources.list

chroot rootfs /bin/bash -c "sudo apt update && sudo apt install -y linux-tools-common"

chroot rootfs /bin/bash -c "cd /usr/local/src/ClockworkPi-linux &&  dpkg -i *.deb"
chroot rootfs /bin/bash -c "apt-mark hold linux-image-6.9.12-v8-raspi linux-headers-6.9.12-v8-raspi linux-libc-dev"

# Sound fix for Ubuntu / Armbian: replaced python3-lgpio install with ClockworkPi APT repo flow for Debian Trixie
chroot rootfs /bin/bash -c "apt update || true"
chroot rootfs /bin/bash -c "apt install -y gnupg wget ca-certificates || true"
chroot rootfs /bin/bash -c "wget -q -O- https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/clockworkpi.gpg >/dev/null"
chroot rootfs /bin/bash -c "echo 'deb [arch=arm64] https://raw.githubusercontent.com/clockworkpi/apt/main/bookworm stable main' | tee /etc/apt/sources.list.d/clockworkpi.list"
chroot rootfs /bin/bash -c "apt update"
chroot rootfs /bin/bash -c "apt install -y uconsole-kernel-cm4-rpi clockworkpi-audio clockworkpi-firmware || true"

chroot rootfs /bin/bash -c "chmod +x /usr/local/bin/sound-patch.py"
chroot rootfs /bin/bash -c "systemctl daemon-reload"
chroot rootfs /bin/bash -c "systemctl enable sound-patch.service"
chroot rootfs /bin/bash -c "systemctl daemon-reload"

chroot rootfs /bin/bash -c "chmod +x /usr/local/bin/uconsole-4g-cm4.py"
chroot rootfs /bin/bash -c "systemctl daemon-reload"
chroot rootfs /bin/bash -c "systemctl enable uconsole-4g-cm4.service"
chroot rootfs /bin/bash -c "systemctl daemon-reload"

##Write this text in /boot/firmware/config.txt
mv rootfs/boot/firmware/config.txt rootfs/boot/firmware/config.txt.bak

cat << 'EOF' > rootfs/boot/firmware/config.txt

# For more options and information see
# http://rptl.io/configtxt
# Some settings may impact device functionality. See link above for details

# Uncomment some or all of these to enable the optional hardware interfaces
#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

# Enable audio (loads snd_bcm2835)
dtparam=audio=on

# Additional overlays and parameters are documented
# /boot/firmware/overlays/README

# Automatically load overlays for detected cameras
camera_auto_detect=1

# Automatically load overlays for detected DSI displays
display_auto_detect=1

# Automatically load initramfs files, if found
auto_initramfs=1

# Enable DRM VC4 V3D driver
#dtoverlay=vc4-kms-v3d

max_framebuffers=2

# Don't have the firmware create an initial video= setting in cmdline.txt.
# Use the kernel's default instead.
#disable_fw_kms_setup=1

# Run in 64-bit mode
arm_64bit=1

# Disable compensation for displays with overscan
disable_overscan=1

# Run as fast as firmware / board allows
arm_boost=1

# Enable host mode on the 2711 built-in XHCI USB controller.
# This line should be removed if the legacy DWC2 controller is required
# (e.g. for USB device mode) or if USB support is not required.
#otg_mode=1

ignore_lcd=1
display_auto_detect=0
dtoverlay=audremap,pins_12_13
dtoverlay=dwc2,dr_mode=host
dtparam=ant2

# Enable DRM VC4 V3D driver (Clockworkpi uConsole CM4)
dtoverlay=clockworkpi-uconsole
dtoverlay=vc4-kms-v3d-pi4,cma-384
dtparam=pciex1=off
dtparam=spi=on
dtparam=drm_fb0_rp1_dsi1
#initial_turbo=0
EOF


mv rootfs/etc/resolv.conf.bak rootfs/etc/resolv.conf
rm rootfs/root/.bash_history

#Unmount the image
sudo umount rootfs/dev/pts
sudo umount rootfs/dev
sudo umount rootfs/proc
sudo umount rootfs/sys
sudo umount rootfs/boot/firmware
sudo umount rootfs

rmdir rootfs


dd if=/dev/loop777 of=uConsole-ubuntu-22.04.5-preinstalled-desktop-arm64+raspi.img bs=4M status=progress
xz -T0 -v uConsole-ubuntu-22.04.5-preinstalled-desktop-arm64+raspi.img

losetup -D


#Flash the xz image
#xzcat uConsole-ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img.xz | dd of=<SELECT BLOCK DEVICE> bs=32M
