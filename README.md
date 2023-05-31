```
How to build SPI image
======================

Install build dependencies:

apt install gcc-10 acpica-tools crossbuild-essential-arm64 nasm \
iasl device-tree-compiler python3-distutils texinfo git subversion \
imagemagick xxd flex bison librsvg2-bin xz-utils uuid-dev libgmp3-dev \
libmpfr-dev libarchive-zip-perl libssl-dev curl

1. Get the sources:

Clone the spi_builder.git repo with submodules:
git clone --recurse-submodules --shallow-submodules git@github.com:Elpitech/spi_builder.git

2. Build the image.

By default, the image is built for the ET101-MB-1.2 rev2 board (the board with
DP/HDMI ports and the HK clone of stm32).

$ make 2>&1 | tee /tmp/make.log

The resulting image is in the ./out dir:
*.full.padded - image for h/w programmer, padded with zeros
*.flash.img - image for software flashing via UEFI Shell

Build options:

To build for other boards, list available targets. For example:

$ make list
$ make BOARD=et121

Sometimes RAM modules do not work well with the default 2400 frequency.  In this
case, you can build an image with non-default (reduced) memory frequency. For
example:
$ make MAX_FREQ=2133

Hardware flashing
=================

Flashing with DB101-D programmer:

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

Flashing with Olimex:

When using other programmers for flashing, please beware of the following:
- The level of UART and SPI signals on ET101 board is 1.8 Volts.
  Do NOT use adapters (USB-UART, SPI, etc) with 3.3 or 5 Volts
  level since the board can be permanently damaged.
- Do NOT plug the standard 20-pin JTAG cable directly into XP8 slot.
  It will damage the board.

You can use Olimex (arm-usb-tiny-h) programmer to flash the image.  Flashrom
shall be at least version 1.2 or higher.

$ sudo apt install libftdi1

Burn full image, where BOARD is the target you have built.
$ sudo flashrom -p ft2232_spi:type=arm-usb-tiny-h,port=A,divisor=8 -w $BOARD.full.padded -c MT25QU256

[Optional] To burn a specific section
$ sudo flashrom -p ft2232_spi:type=arm-usb-tiny-h,port=A,divisor=8 -w $BOARD.full.padded -c MT25QU256 -l img/{BOARD}.layout -i scp


Software flashing via UEFI application
======================================

You can flash the image via UEFI shell with a dedicated software flasher. After
the build the SPI flasher will be available in
uefi/Build/Baikal/RELEASE_GCC5/AARCH64/SpiFlash.efi

- Transfer the SpiFlash.efi EFI flashing module and the *.flash.img file
  to a USB stick formatted with FAT32.
- Boot the board and go to the BIOS menu by pressing 'Esc'
- Go to "Boot Manager"/"UEFI Shell"
- Press 'Esc' to interrupt the booting and go to the interactive UEFI Shell
- Go to the USB device (FS0) and run the flasher file:

FS0:\> SpiFlash.efi 0 et101-dp.flash.img

- Once the flashing finishes with the 'success' message, reset the board:

FS0:\> reset

The board will boot, initialize its environment for about a minute, and then
will reboot again.
```
