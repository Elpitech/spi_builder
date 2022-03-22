# How to flash TF307 board firmware

## BIG RED WARNING

1. **The level of UART and SPI signals on TF307 is 1.8 Volts.**
2. **DO NOT use adapters (USB-UART, SPI, etc) with 3.3 or 5 Volts
level since the board can be permanently damaged!**


## Required hardware

1. [Olimex ARM-USB-OCD-H JTAG](https://www.olimex.com/Products/ARM/JTAG/ARM-USB-OCD-H)
2. [FT232 USB UART board](https://www.chipdip.ru/product/ft232-usb-uart-board-type-a)
3. Another computer (will be called `host` in this document)


## Required software (on the host computer)

1. flashrom, version 1.2 or newer. Previous versions are known to **NOT** work
2. picocom, version 2.2 (most likely older versions work too)
3. sudo and sudo access

For the automated flashing the following tools are also necessary:

1. python3, version 3.6 or newer, previous versions are known to NOT work
2. python3-serial, version 3.4 is known to work
3. `lsusb` from usbutils, version 012 is known to work (most likely older versions work too)
4. `udevadm` from udev, version 246 is known to work (most likely older versions work too)


## Connecting devices

**BIG RED WARNING #1**: **DON'T plug the standard 20-pin JTAG cable directly into `XP8`**!
**BIG RED WARNING #2**: **make sure USB UART uses 1.8 Volts level, otherwise the board can be permanently damaged!**

Both JTAG and USB-UART adapter should be attached to the `XP8` connector.


| XP8 TF307 pin |       |  ARM-USB-OCD-H pin  |        |
| :-----------: | :---: | :-----------------: | :----: |
|  `BOOT_SS`    |   5   |      `TTMS`         |   7    |
|  `BOOT_CLK`   |   7   |      `TTCK`         |   9    |
|  `BOOT_MISO`  |   9   |      `TTDO`         |   13   |
|  `BOOT_MOSI`  |   11  |      `TTDI`         |   5    |
|  `VREF1V8`    |   18  |      `Vref`         |   1    |
|  `GND`        |   6   |      `GND`          | 4 - 20 |


|     XP8 TF307 pin        |       | FT232 USB UART pin |
| :----------------------: | :---: | :----------------: |
|  `CONN_UART_TX_TO_BMC`   |   17  |       RX           |
|  `CONN_UART_RX_FROM_BMC` |   19  |       TX           |
|   GND                    |   14  |       GND          |


Also you might want to connect to the UART console of BE-M1000 itself
(to check if the board is able to boot, etc).
Note: extra USB-UART adapter is required

|     XP8 TF307 pin           |       | FT232 USB UART pin |
| :-------------------------: | :---: | :----------------: |
|  `BM_UART0_TX_TO_CONSOLE`   |   13  |       RX           |
|  `BM_UART0_RX_FROM_CONSOLE` |   15  |       TX           |
|  `GND`                      |   10  |       GND          |


Yeah, this is messy.


## Manual flashing

Initial state: 

* The board is physically powered off (the power cord is disconnected)
* Olimex ARM-USB-OCD-H JTAG is plugged into the host computer
* FT232 USB UART is plugged into the host computer

1. Power on the ATX power supply (attach the power cord), however **don't** power on the board yet.
2. Figure out the device node which corresponds to FT232 USB UART (the one which
   is attached to TO/FROM BMC pins). For instance, if a single FT232 USB UART
   is connected to the host computer:
   ```
   ls -l /dev/serial/by-id/ | grep FTDI
   lrwxrwxrwx 1 root root 13 Jun 29 13:19 usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0 -> ../../ttyUSBNNN
   ```
   The device node is `/dev/ttyUSBNNN`
3. Connect to the BMC console:
   ```
   picocom -b115200 /dev/ttyUSBNNN
   ```
4. For TP-TF307-MB-A0, TF307-MB-S-C boards: run the following commands in BMC console:
   1. `pins set 7`
   On success BMC prints `Set pin[7] BM_SPI_SEL`
   2. `pins set 19`
   On success BMC powers on the board and prints `Set pin[19] ATX_PSON`
   3. pins set 23
   On success BMC replies `Set pin[23] EN_1V8`
5. For TF307-MB-S-D board run the following commands in BMC console:
   1. `pins set 11`
   On success BMC prints `Set pin 11 (BM_SPI_SEL)`
   2. `pins set 16`
   On success BMC powers on the board an prints `Set pin 16 (ATX_PSON)`
   3. `pins set 26`
   On success prints `Set pin 26 (EN_1V8)`
6. Make a backup:
   ```
   sudo flashrom -p ft2232_spi:type=arm-usb-ocd-h,port=A,divisor=8 -c MT25QU256 -r tf307-firmware.bak.bin
   ```
7. Flash the new firmware:
   ```
   sudo flashrom -p ft2232_spi:type=arm-usb-ocd-h,port=A,divisor=8 -c MT25QU256 -w mbm20.full.img
   ```
   `flashrom` will warn that chip hasn't been tested:
   ```
    flashrom v1.2 on Linux 5.8.0-53-generic (x86_64)
    flashrom is free software, get the source code at https://flashrom.org

    Using clock_gettime for delay loops (clk_id: 1, resolution: 1ns).
    Found Micron flash chip "MT25QU256" (32768 kB, SPI) on ft2232_spi.
    ===
    This flash part has status UNTESTED for operations: PROBE READ ERASE WRITE
    The test status of this chip may have been updated in the latest development
    version of flashrom. If you are running the latest development version,
    please email a report to flashrom@flashrom.org if any of the above operations
    work correctly for you with this flash chip. Please include the flashrom log
    file for all operations you tested (see the man page for details), and mention
    which mainboard or programmer you tested in the subject line.
    Thanks for your help!
   ```
   The warning is harmless, please ignore it.
   Next it will print
   ```
   Reading old flash chip contents...
   ```
   (this takes about 30 seconds)
   and
   ```
   Erasing and writing flash chip...
   Erase/write done
   Verifying flash...
   VERIFIED
   ```
8. Run the following commands in BMC console
   1. `pins bootseq`
   On success this prints
   ```
   L: [SHELL] Starting boot sequence
   E: [MB1BM1_PINS] PWG is active when 1.8 V voltage regulator is disabled
   L: [SHELL] Boot sequence finished
   ```
   2. `pins board_off`
   This prints
   ```
   L: [SHELL] Pins are reset to board off state
   L: [MB1BM1_PINS] Wake up requested
   L: [RTC] Current date 12.03.21, time 07:32:09
   ```
   3. `pins board_off` (yes, repeat the same command)
   On success it prints
   ```
   L: [SHELL] Pins are reset to board off state
   ```

## Automated flashing

Initial state is the same as for manual flashing:

* The board is physically powered off (the power cord is disconnected)
* Olimex ARM-USB-OCD-H JTAG is plugged into the host computer
* FT232 USB UART is plugged into the host computer

1. Power on the ATX power supply (attach the power cord), however **don't** power on the board yet.
2. Wait 30 seconds (so BMC has enough time to initialize itself).

3. Run

```
./tf307_fwupd.py mbm20.full.img
```

This will automatically detect the programmer and the BMC console, figure
out the board revision, run BMC commands, actually flash the firmware,
and power off the board.

Note 1: by default the script skips `fat` and `vars` (EFI variables) sections.
Use `--full` to flash the complete image.

Note 2: if autodetection fails (or you don't trust it) programmer type,
BMC console, and board revision can be explicitly specified, run 
```
./tf307_fwupd.py --help
```
for the details.

Note 3: the script does not check if the given firmware file is suitable
for the board. However flashing a wrong firmware is not fatal (for it's
possible to flash the correct one).
