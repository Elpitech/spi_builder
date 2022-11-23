```
How to build SPI image
======================

Install build dependencies:

apt install gcc-10 acpica-tools crossbuild-essential-arm64 nasm \
iasl device-tree-compiler python3-distutils texinfo git subversion \
imagemagick xxd flex bison librsvg2-bin xz-utils uuid-dev libgmp3-dev \
libmpfr-dev libarchive-zip-perl libssl-dev curl

1. Setup the kernel/arm-tf/edk2 source paths in the Makefile

For example:
KERNEL_GIT := git@github.com:Elpitech/baikal-m-linux-kernel.git -b linux-5.10-elp
ARMTF_GIT := git@github.com:Elpitech/arm-tf.git -b $(SDK_VER)-elp
EDK2_PLATFORM_SPECIFIC_GIT := git@github.com:Elpitech/edk2-platform-baikal.git -b $(SDK_VER)-elp

2. Build the image.

By default, the image is built for the ET101-MB-1.2 rev2 board (the board with
DP/HDMI ports and the HK clone of stm32).

$ make 2>&1 | tee /tmp/make.log

The resulting image is in the ./out dir:
*.full.padded - image for h/w programmer, padded with zeros
*.flash.img - image for software flashing via UEFI Shell

Building for a non-default board:

List available targets
$ make list

HDMI/LVDS board et101-mb-1.1-rev2 (same for et101-mb-1.1-rev1.1 with genuine stm32):
$ make BOARD=et101-v2-lvds

HDMI/DP board et101-mb-1.2-rev2 (same for et101-mb-1.2-rev1.2 with genuine stm32):
$ make BOARD=et101-v2-dp

The couple of earlier boards with genuine stm32 chips have dedicated *.dts files
with some extended functionality not available on the clones.  These boards are
not manufactured anymore, but you can build dedicated images for them anyways:

et101-mb-1.1-rev1.1:
$ make BOARD=et101-lvds
et101-mb-1.2-rev1.2 
$ make BOARD=et101-dp

Sometimes RAM modules do not work well with the default 2400 frequency.  In this
case, you can build an image with non-default (reduced) memory frequency:
$ make BOARD=et101-v2-dp MAX_FREQ=2133

Hardware flashing
=================

The following instructions assume the DB101-C programmer board is used.
If using something else, please beware of the following:
- The level of UART and SPI signals on ET101 board is 1.8 Volts.
  Do NOT use adapters (USB-UART, SPI, etc) with 3.3 or 5 Volts
  level since the board can be permanently damaged.
- Do NOT plug the standard 20-pin JTAG cable directly into XP8 slot.
  It will damage the board.

Configure BMC console file for minicom:

[~/.minirc.S2]
pu port             /dev/ttyUSB2
pu baudrate         115200
pu bits             8
pu parity           N
pu stopbits         1
pu backspace        BS
pu rtscts           No
pu linewrap         Yes

# Connect to BMC console
$ minicom -C ses.log S2

Run the commands

>:pins bootseq
>:pins cpu_off

# Burn full image, where BOARD is the target you have built.
$ sudo flashrom -p serprog:dev=/dev/ttyACM0:4000000 -c MT25QU256 -w $BOARD.full.padded
If chip is not found, try a different one or omit -c option:
$ sudo flashrom -p serprog:dev=/dev/ttyACM0:4000000 -c W25Q256.W -w $BOARD.full.padded

Upon success, type in BMC console:

>:pins board_off

Software flashing via UEFI application
======================================

Alternatively, you flash the image via UEFI shell with a dedicated software
flasher. Build the image first. Next build the flashing UEFI app:

$ make BOARD=et101-dp
$ make SPI_FLASHER=1 BOARD=et101-dp uefi
$ find . -name SpiFlashImage.efi

SpiFlashImage.efi includes the flasher and the bundled *.flash.img file.

- Create the USB flash stick with FAT32
- Transfer the SpiFlashImage.efi EFI flashing module to USB. This
  module contains the flasher and the ROM image.
- Boot the board and go to the BIOS menu by pressing 'Esc'
- Go to "Boot Manager"/"UEFI Shell"
- Press 'Esc' to interrupt the booting and go to the interactive UEFI Shell
- Go to the USB device (FS0) and run the flasher file:

Shell> fs0:
FS0:\> SpiFlashImage.efi

Alternatively, if using the stand-alone flasher SpiFlash.efi, make sure you
provide it with the *.flash.img file as argument. Other image formats are not
suitable.

FS0:\> SpiFlash.efi 0 et101-dp.flash.img

- Once the flashing finishes with the 'success' message, reset the board:

FS0:\> reset

The board will boot, initialize its environment, and then will reboot again.

Building/flashing for other boards
==================================

For TF307 boards:
$ make BOARD=mitx-d

[Optional] To build for older SDK:
$ make SDK_MAJOR_REV=4 SDK_MINOR_REV=4 BOARD=mitx-d

For TF307 boards, see tf307_flashing.md for more detailed instructions.

You can use flashrom and Olimex (arm-usb-tiny-h) programmer to flash the image.
Flashrom shall be at least version 1.2 or higher.

sudo apt install libftdi1

Burn full image, where BOARD is the target you have built.
$ sudo flashrom -p ft2232_spi:type=arm-usb-tiny-h,port=A,divisor=8 -w $BOARD.full.padded -c MT25QU256

[Optional] To burn a specific section
$ sudo flashrom -p ft2232_spi:type=arm-usb-tiny-h,port=A,divisor=8 -w $BOARD.full.padded -c MT25QU256 -l mitx-d.layout -i scp

Building a debug module
=======================

To build a debug module separate from the SPI image:

Comment out the required module in ArmBaikalPkg/ArmBaikalBfkm.fdf.inc. For example:
#INF ArmBaikalPkg/Drivers/BaikalEthDxe/BaikalEthDxe.inf

Set UEFI_BUILD_TYPE = DEBUG in the Makefile and run:

$ make uefi

Copy the debug version of the module to USB flash:
cp  ../baikal-m/uefi/Build/ArmBaikalBfkm-AARCH64/DEBUG_GCC6/AARCH64/BaikalEthDxe.efi /media/ndz/B03B-6A17/
umount /media/ndz/B03B-6A17

Insert the USB flash and boot. During boot, add the module via menu "Add driver options".
```
