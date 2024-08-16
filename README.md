# uConsole-Image-Builder
A collection of BASH scripts to create a image for the uConsole CM4.

# Usage:

```(as root)# ./create_image.sh [UBUNTU | DEBIAN | ARMBIAN]```

It will first create the ```.deb``` package for the gpio related scripts and services.

After that, it will compile ```@ak-rex``` kernel with the drivers for ```uConsole - CM4```.

After that, it will download and prepare the image for your desired distro.

The script takes around 2h30m to complete on a CM4. After it finishes, you will
find an ```.xz``` compressed image whose name starts by uConsole-.

