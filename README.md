```
How to build SPI image
======================

To build mitx.full.padded:

Setup the kernel source and cross tools in the Makefile.

Build the image for your target. For example:

For TF307 boxes with HDMI:
$ make BOARD=mitx-d

Alternatively, for monoblocks with LVDS:
$ make BOARD=mitx-d-lvds

To build for older SDK:
$ make SDK_MAJOR_REV=4 SDK_MINOR_REV=4 BOARD=mitx-d

To build a debug module separate from the SPI image:

Comment out the required module in ArmBaikalPkg/ArmBaikalBfkm.fdf.inc. For example:
#INF ArmBaikalPkg/Drivers/BaikalEthDxe/BaikalEthDxe.inf

Set UEFI_BUILD_TYPE = DEBUG in the Makefile and run:

$ make uefi

Copy the debug version of the module to USB flash:
cp  ../baikal-m/uefi/Build/ArmBaikalBfkm-AARCH64/DEBUG_GCC6/AARCH64/BaikalEthDxe.efi /media/ndz/B03B-6A17/
umount /media/ndz/B03B-6A17

Insert the USB flash and boot. During boot, add the module via menu "Add driver options".

How to burn the image to SPI
============================

sudo apt install libftdi1

# Connect to BMC console
$ minicom -C ses.log S2

You need to set ATX_PSON and EN_1V8 pins. Either do it directly with 'pins list'
and 'pins set', or just run:

>:pins bootseq
>:pins cpu_off

# You will need at least flashrom-v1.2 installed. If it is not available in the
# repo, just build the current flashrom from source. You will need libftdi-dev
# installed first.

# Burn full image, where BOARD is the target you have built.
$ sudo flashrom -p ft2232_spi:type=arm-usb-tiny-h,port=A,divisor=8 -w $BOARD.full.padded -c MT25QU256

# Burn a specific section
$ sudo flashrom -p ft2232_spi:type=arm-usb-tiny-h,port=A,divisor=8 -w $BOARD.full.padded -c MT25QU256 -l mitx-d.layout -i scp


Upon success, type in BMC console:

>:pins board_off
```
