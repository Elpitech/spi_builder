```
How to build SPI image
======================

1. Setup the kernel/arm-tf/edk2 source paths and cross tool path in the Makefile.

2. Build the image. By default, the ET101 image is built.

$ make 2>&1 | tee /tmp/make.log

The resulting image is in img/et101.full.padded

How to burn the image to ET101's SPI
====================================

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

Upon success, type in BMC console:

>:pins board_off

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
