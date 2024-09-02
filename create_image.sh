#!/bin/bash


############################################################################################################
# This script is for the ClockworkPi Devterm and uConsole. It will compile a custom kernel                 #
# for the Raspberry Pi Compute Module 4 and install it on an Ubuntu 22.04.4 image.                         #
############################################################################################################

### Instructions ###
# 1. On an Ubuntu or Debian amd64 oe arm64 host machine, download and run this script as sudo.
# 2. The script will download the Ubuntu 22.04.4 image, clone the ak-rex kernel, compile the kernel, and install it on the image.
# 3. Flash the image to a microSD card and insert it into the Devterm, uConsole, or GameShell.
# 4. Boot the device and enjoy the new kernel.

# Usage: ./create_uconsole_image.sh [DEBIAN | UBUNTU | ARMBIAN_NOBLE | ARMBIAN_BUSTER]

#If @1 is not provided, default to UBUNTU
if [ -z "$1" ]; then
    OS="UBUNTU"
else
    OS=$1
fi

#Create GPIO package
./make_gpio_package.sh

#Clone ak-rex kernel from github
git clone https://github.com/ak-rex/ClockworkPi-linux.git
cd ClockworkPi-linux
git checkout rpi-6.9.y
git pull

#Compile the kernel
sudo apt install -y bc bison flex libssl-dev make libc6-dev libncurses5-dev debhelper-compat 
sudo apt install -y crossbuild-essential-arm64
losetup -D

if [ $OS == "UBUNTU" ]; then
    KERNEL=kernel8
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
    
    #make-kpkg nconfig
    #make deb-pkg -j4 LOCALVERSION=-raspi KDEB_PKGVERSION=1
    
    #chmod a+x debian/rules
    #chmod a+x debian/scripts/*
    #chmod a+x debian/scripts/misc/*
    #fakeroot debian/rules clean
    #fakeroot debian/rules editconfigs 
    
    make -j`nproc --all` LOCALVERSION=-raspi KDEB_PKGVERSION=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- deb-pkg 
    
    cd ..

    wget https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img.xz

    #Extract the image
    unxz ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img.xz
    
    #Mount the image
    losetup -D
    losetup /dev/loop777 -P ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img

    mkdir rootfs
    mount /dev/loop777p2 rootfs    
    mkdir rootfs/boot/firmware
    mount /dev/loop777p1 rootfs/boot/firmware

elif [ $OS == "ARMBIAN_NOBLE" ]; then
    ### NOTE: The script should work too for Armbian, but it is not tested yet. ###


    #1. download armbian image
    if [ $OS == "ARMBIAN_BUSTER" ]; then
       wget https://dl.armbian.com/rpi4b/archive/Armbian_24.5.3_Rpi4b_bookworm_current_6.6.35_minimal.img.xz
       unxz Armbian_24.5.3_Rpi4b_bookworm_current_6.6.35_minimal.img.xz
       losetup -f -P Armbian_24.5.3_Rpi4b_bookworm_current_6.6.35_minimal.img
    fi
    if [ $OS == "ARMBIAN_NOBLE" ]; then
       wget https://dl.armbian.com/rpi4b/archive/Armbian_24.5.1_Rpi4b_noble_current_6.6.31_gnome_desktop.img.xz
       unxz Armbian_24.5.1_Rpi4b_noble_current_6.6.31_gnome_desktop.img.xz
       losetup -f -P Armbian_24.5.1_Rpi4b_noble_current_6.6.31_gnome_desktop.img
    fi
    ## Compile the kernel
    ## Uncompress the image
    ## Mount the image
else
    #DEBIAN
    KERNEL=kernel8
    
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
    #make menuconfig
    make -j`nproc --all` LOCALVERSION=-raspi KDEB_PKGVERSION=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- deb-pkg 
    cd ..

    wget https://raspi.debian.net/tested/20231109_raspi_4_bookworm.img.xz
    unxz 20231109_raspi_4_bookworm.img.xz


    # Mount the image
    mkdir rootfs
    losetup -D
    losetup /dev/loop777 -P  20231109_raspi_4_bookworm.img
    mount /dev/loop777p2 rootfs   
    mkdir rootfs/boot/firmware
    mount /dev/loop777p1 rootfs/boot/firmware
fi

mount --bind /dev rootfs/dev
mount --bind /dev/pts rootfs/dev/pts
mount --bind /proc rootfs/proc
mount --bind /sys rootfs/sys

mv rootfs/etc/resolv.conf rootfs/etc/resolv.conf.bak
cp /etc/resolv.conf rootfs/etc/resolv.conf

#Copy the .deb files to the image chroot environment and install them
cp linux-image-6.9.9-v8-raspi_1_arm64.deb rootfs/usr/local/src
cp linux-headers-6.9.9-v8-raspi_1_arm64.deb rootfs/usr/local/src
cp linux-libc-dev_1_arm64.deb rootfs/usr/local/src
cp uconsole-cm4-gpio.deb rootfs/usr/local/src
#cp linux-upstream_1_.orig.tar.xz rootfs/usr/local/src

chroot rootfs /bin/bash -c "apt purge -y --allow-change-held-packages linux-image* linux-headers*"

chroot rootfs /bin/bash -c "cd /usr/local/src &&  dpkg -i linux-headers-6.9.9-v8-raspi_1_arm64.deb linux-image-6.9.9-v8-raspi_1_arm64.deb linux-libc-dev_1_arm64.deb uconsole-cm4-gpio.deb"
chroot rootfs /bin/bash -c "apt-mark hold linux-image-6.9.9-v8-raspi linux-headers-6.9.9-v8-raspi"

chroot rootfs /bin/bash -c "cd /boot/ && rm initrd.img initrd.img.old vmlinuz vmlinuz.old"
chroot rootfs /bin/bash -c "cd /boot/ && ln -s vmlinuz-6.9.9-v8-raspi vmlinuz"
chroot rootfs /bin/bash -c "cd /boot/ && ln -s initrd.img-6.9.9-v8-raspi initrd.img"
chroot rootfs /bin/bash -c "cp /usr/lib/linux-image-6.9.9-v8-raspi/overlays/** /boot/firmware/overlays/"
chroot rootfs /bin/bash -c "cp /usr/lib/linux-image-6.9.9-v8-raspi/broadcom/** /boot/firmware/"
chroot rootfs /bin/bash -c "cp /boot/vmlinuz-6.9.9-v8-raspi /boot/firmware/vmlinuz"

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

if [ $OS == "UBUNTU" ]; then
    dd if=/dev/loop777 of=uConsole-ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img bs=4M status=progress
    xz -T0 -v uConsole-ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img  
elif [ $OS == "ARMBIAN_NOBLE" ]; then  
    dd if=/dev/loop777 of=uConsole-Armbian_24.5.1_Rpi4b_noble_current_6.6.31_gnome_desktop.img bs=4M status=progress
    xz -T0 -v uConsole-Armbian_24.5.1_Rpi4b_noble_current_6.6.31_gnome_desktop.img
elif [ $OS == "ARMBIAN_BUSTER" ]; then
    dd if=/dev/loop777 of=uConsole-Armbian_24.5.3_Rpi4b_bookworm_current_6.6.35_minimal.img bs=4M status=progress
    xz -T0 -v uConsole-Armbian_24.5.3_Rpi4b_bookworm_current_6.6.35_minimal.img
else
    dd if=/dev/loop777 of=uConsole-20231109_raspi_4_bookworm.img bs=4M status=progress
    xz -T0 -v uConsole-20231109_raspi_4_bookworm.img
fi

losetup -D


#Flash the xz image
#xzcat uConsole-ubuntu-22.04.4-preinstalled-desktop-arm64+raspi.img.xz | dd of=<SELECT BLOCK DEVICE> bs=32M
#xzcat uConsole-Armbian_24.5.1_Rpi4b_noble_current_6.6.31_gnome_desktop.img.xz | dd of=<SELECT BLOCK DEVICE> bs=32M
#xzcat uConsole-Armbian_24.5.3_Rpi4b_bookworm_current_6.6.35_minimal.img.xz | dd of=<SELECT BLOCK DEVICE> bs=32M
#xzcat uConsole-20231109_raspi_4_bookworm.img.xz | dd of=<SELECT BLOCK DEVICE> bs=32M


