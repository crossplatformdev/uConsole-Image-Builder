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
mount /dev/loop777p2 rootfs    
mkdir rootfs/boot/firmware
mount /dev/loop777p1 rootfs/boot/firmware


mount --bind /dev rootfs/dev
mount --bind /dev/pts rootfs/dev/pts
mount --bind /proc rootfs/proc
mount --bind /sys rootfs/sys

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

chroot rootfs /bin/bash -c "apt update && apt install -y linux-tools-common"

chroot rootfs /bin/bash -c "cd /usr/local/src/ClockworkPi-linux &&  dpkg -i *.deb"
chroot rootfs /bin/bash -c "apt-mark hold linux-image-6.9.12-v8-raspi linux-headers-6.9.12-v8-raspi linux-libc-dev"

#echo "APT::Default-Release \"jammy\"" >> rootfs/etc/apt/apt.conf.d/01-vendor-ubuntu

## Sound fix for Ubuntu / Armbian
chroot rootfs /bin/bash -c "apt update"
chroot rootfs /bin/bash -c "apt install -y python3-lgpio"

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

[all]
kernel=vmlinuz
cmdline=cmdline.txt
initramfs initrd.img followkernel

camera_auto_detect=1
display_auto_detect=1

# Config settings specific to arm64
arm_64bit=1

disable_overscan=1
dtparam=audio=on

max_framebuffers=2

ignore_lcd=1
dtoverlay=dwc2,dr_mode=host
dtoverlay=vc4-kms-v3d-pi4,cma-384
#dtoverlay=clockworkpi-devterm
dtoverlay=clockworkpi-uconsole
dtoverlay=audremap,pins_12_13

dtparam=spi=on
#dtparam=ant2

##Comment out the device not needed in [all]
dtparam=pciex1_gen=3
gpu_mem=256
EOF


mv rootfs/etc/resolv.conf.bak rootfs/etc/resolv.conf
rm rootfs/root/.bash_history

#Unmount the image
umount rootfs/dev/pts
umount rootfs/dev
umount rootfs/proc
umount rootfs/sys
umount rootfs/boot/firmware
umount rootfs

rmdir rootfs

dd if=/dev/loop777 of=uConsole-ubuntu-22.04.5-preinstalled-desktop-arm64+raspi.img bs=4M status=progress
xz -T0 -v uConsole-ubuntu-22.04.5-preinstalled-desktop-arm64+raspi.img

losetup -D


#Flash the xz image
#xzcat uConsole-ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img.xz | dd of=<SELECT BLOCK DEVICE> bs=32M


