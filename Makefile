#CROSS ?= aarch64-linux-gnu-
CROSS = $(HOME)/toolchains/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-
BOARD ?= et101
SPI_FLASHER ?= 0

SDK_VER := 5.4
SDK_REV = 0x54
PLAT = bm1000

#KERNEL_GIT := git@github.com:Elpitech/baikal-m-linux-kernel.git -b linux-5.4-elp
#ARMTF_GIT := git@github.com:Elpitech/arm-tf.git -b $(SDK_VER)-elp
#EDK2_PLATFORM_SPECIFIC_GIT := git@github.com:Elpitech/edk2-platform-baikal.git -b $(SDK_VER)-elp

KERNEL_GIT := git@gitlab.elpitech.ru:baikal-m/kernel.git -b linux-5.4-elp
ARMTF_GIT := git@gitlab.elpitech.ru:baikal-m/arm-tf.git -b $(SDK_VER)-elp
EDK2_PLATFORM_SPECIFIC_GIT := git@gitlab.elpitech.ru:baikal-m/edk2-platform-baikal.git -b $(SDK_VER)-elp

# End of user configurable parameters

TOP_DIR := $(shell pwd)
ARMTF_DIR := $(TOP_DIR)/arm-tf
UEFI_DIR := $(TOP_DIR)/uefi
KBUILD_DIR := $(TOP_DIR)/kbuild

# Newer UEFI in SDK 5.1 is coupled with the upstream code. Only
# platform-specific part comes from our sources.
EDK2_GIT := http://github.com/tianocore/edk2.git
EDK2_NON_OSI_GIT := https://github.com/tianocore/edk2-non-osi.git

ifeq ($(BOARD),mitx)
	BE_TARGET = mitx
	BOARD_VER = 0
else ifeq ($(BOARD),mitx-d)
	BE_TARGET = mitx
	BOARD_VER = 2
else ifeq ($(BOARD),mitx-d-lvds)
	BE_TARGET = mitx
	BOARD_VER = 2
else ifeq ($(BOARD),e107)
	BE_TARGET = mitx
	BOARD_VER = 1
else ifeq ($(BOARD),et101)
	BE_TARGET = mitx
	BOARD_VER = 2
else ifeq ($(BOARD),et101-dp)
	BE_TARGET = mitx
	BOARD_VER = 2
	ARMTF_DEFS = "DP_ENABLE=1"
else ifeq ($(BOARD),et101-lvds)
	BE_TARGET = mitx
	BOARD_VER = 2
else ifeq ($(BOARD),et111)
	BE_TARGET = mitx
	BOARD_VER = 3
	ARMTF_DEFS = "EDP_ENABLE=1"
else ifeq ($(BOARD),em407)
	BE_TARGET = mitx
	BOARD_VER = 4
endif

DUAL_FLASH ?= no
ARMTF_DEFS += "DUAL_FLASH=$(DUAL_FLASH)"
ifeq ($(V),1)
ARMTF_DEFS += "V=1"
endif
UEFI_BUILD_TYPE ?= RELEASE
#UEFI_BUILD_TYPE = DEBUG
ARMTF_DEBUG ?= 0
ifeq ($(ARMTF_DEBUG),0)
ARMTF_BUILD_TYPE = release
else
ARMTF_BUILD_TYPE = debug
endif

SCP_BLOB = ./prebuilts/bm1000-scp.bin

ARCH = arm64
NCPU := $(shell nproc)

IMG_DIR := $(CURDIR)/img

#TARGET_CFG = $(BE_TARGET)_defconfig
TARGET_CFG = et101_defconfig
TARGET_DTB = baikal/bm-$(BOARD).dtb
KERNEL_FLAGS = O=$(KBUILD_DIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) -C $(TOP_DIR)/kernel

UEFI_FLAGS = -DFIRMWARE_VERSION_STRING=$(SDK_VER) -DFIRMWARE_REVISION=$(SDK_REV)
UEFI_PLATFORM = Platform/Baikal/BM1000Rdb/BM1000Rdb.dsc
UEFI_FLAGS += -DFIRMWARE_VENDOR="Elpitech"
ifeq ($(BE_TARGET),mitx)
	UEFI_FLAGS += -DBAIKAL_MITX=TRUE -DBOARD_VER=$(BOARD_VER)
endif
ifeq ($(SPI_FLASHER),1)
UEFI_FLAGS += -DBUILD_UEFI_APPS=TRUE
endif

ARMTF_BUILD_DIR = $(ARMTF_DIR)/build/$(PLAT)/$(ARMTF_BUILD_TYPE)
BL1_BIN = $(ARMTF_BUILD_DIR)/bl1.bin
FIP_BIN = $(ARMTF_BUILD_DIR)/fip.bin

all: setup bootrom

setup:
	mkdir -p img
ifeq ($(SRC_ROOT),)
	mkdir -p $(UEFI_DIR)
	[ -d $(TOP_DIR)/arm-tf ] || (git clone $(ARMTF_GIT))
	[ -d $(UEFI_DIR)/edk2 ] || (cd $(UEFI_DIR) && git clone $(EDK2_GIT) && cd edk2 && git checkout 06dc822d045 && git submodule update --init)
	[ -d $(UEFI_DIR)/edk2-non-osi ] || (cd $(UEFI_DIR) && git clone $(EDK2_NON_OSI_GIT) && cd edk2-non-osi && git checkout master)
	[ -d $(UEFI_DIR)/edk2-platform-baikal ] || (cd $(UEFI_DIR) && git clone $(EDK2_PLATFORM_SPECIFIC_GIT))
	[ -d $(TOP_DIR)/kernel ] || (git clone $(KERNEL_GIT) kernel)
else
	[ -d $(TOP_DIR)/arm-tf ] || (mkdir arm-tf && cd $(SRC_ROOT)/arm-tf && cp -pR * $(TOP_DIR)/arm-tf)
	[ -d $(UEFI_DIR)/edk2 ] || (mkdir -p $(UEFI_DIR)/edk2 && cd $(SRC_ROOT)/edk2 && cp -pR * $(UEFI_DIR)/edk2)
	[ -d $(UEFI_DIR)/edk2-non-osi ] || (mkdir $(UEFI_DIR)/edk2-non-osi && cd $(SRC_ROOT)/edk2-non-osi && cp -pR * $(UEFI_DIR)/edk2-non-osi)
	[ -d $(UEFI_DIR)/edk2-platform-baikal ] || (mkdir $(UEFI_DIR)/edk2-platform-baikal && cd $(SRC_ROOT)/edk2-platform-baikal && cp -pR * $(UEFI_DIR)/edk2-platform-baikal)
	[ -d $(TOP_DIR)/kernel ] || (mkdir $(TOP_DIR)/kernel && mkdir -p $(KBUILD_DIR) && cd $(SRC_ROOT)/kernel && cp -pR * $(TOP_DIR)/kernel)
endif

# Note: BaseTools cannot be built in parallel.
basetools:
	BIOS_WORKSPACE=$(UEFI_DIR) ./buildbasetools.sh

uefi $(IMG_DIR)/$(BOARD).efi.fd: basetools
	mkdir -p img
	rm -f $(IMG_DIR)/$(BOARD).efi.fd
	rm -rf $(UEFI_DIR)/Build
	SDK_VER=$(SDK_VER) BIOS_WORKSPACE=$(UEFI_DIR) CROSS=$(CROSS) BUILD_TYPE=$(UEFI_BUILD_TYPE) UEFI_FLAGS="$(UEFI_FLAGS)" UEFI_PLATFORM="${UEFI_PLATFORM}" SPI_FLASHER=$(SPI_FLASHER) FLASH_IMG=${IMG_DIR}/${BOARD}.flash.img ./builduefi.sh
	cp $(UEFI_DIR)/Build/Baikal/$(UEFI_BUILD_TYPE)_GCC5/FV/BAIKAL_EFI.fd $(IMG_DIR)/$(BOARD).efi.fd

arm-tf $(IMG_DIR)/$(BOARD).fip.bin $(IMG_DIR)/$(BOARD).bl1.bin: $(IMG_DIR)/$(BOARD).efi.fd
	if [ -d $(ARMTF_DIR)/build ]; then \
		OLD_BOARD=$$(cat $(ARMTF_DIR)/build/subtarget); \
		if [ "x$(BOARD)" != "x$$OLD_BOARD" ] ; then \
			echo "OLD_BOARD = $$OLD_BOARD"; \
			rm -rf $(ARMTF_DIR)/build; \
			mkdir -p $(ARMTF_DIR)/build; \
		fi; \
	else \
		mkdir -p $(ARMTF_DIR)/build; \
	fi
	echo $(BOARD) > $(ARMTF_DIR)/build/subtarget
	$(MAKE) -j$(NCPU) CROSS_COMPILE=$(CROSS) BAIKAL_TARGET=$(BE_TARGET) BOARD_VER=$(BOARD_VER) $(ARMTF_DEFS) PLAT=$(PLAT) DEBUG=$(ARMTF_DEBUG) LOAD_IMAGE_V2=0 -C $(ARMTF_DIR) all
	$(MAKE) -j$(NCPU) CROSS_COMPILE=$(CROSS) BAIKAL_TARGET=$(BE_TARGET) BOARD_VER=$(BOARD_VER) $(ARMTF_DEFS) PLAT=$(PLAT) DEBUG=$(ARMTF_DEBUG) LOAD_IMAGE_V2=0 BL33=$(IMG_DIR)/$(BOARD).efi.fd -C $(ARMTF_DIR) fip
	cp $(FIP_BIN) $(IMG_DIR)/$(BOARD).fip.bin
	cp $(BL1_BIN) $(IMG_DIR)/$(BOARD).bl1.bin

bootrom: $(IMG_DIR)/$(BOARD).fip.bin $(IMG_DIR)/$(BOARD).dtb
	IMG_DIR=$(IMG_DIR) BOARD=$(BOARD) SCP_BLOB=$(SCP_BLOB) DUAL_FLASH=$(DUAL_FLASH) ./genrom.sh

dtb $(IMG_DIR)/$(BOARD).dtb: 
	mkdir -p $(KBUILD_DIR)
	$(MAKE) -j$(NCPU) $(KERNEL_FLAGS) $(TARGET_CFG)
	$(MAKE) -j$(NCPU) $(KERNEL_FLAGS) $(TARGET_DTB)
	cp $(KBUILD_DIR)/arch/$(ARCH)/boot/dts/$(TARGET_DTB) $(IMG_DIR)/$(BOARD).dtb

clean:
	rm -rf $(KBUILD_DIR)
	rm -rf $(UEFI_DIR)/Build
	rm -f basetools
	rm -rf $(IMG_DIR)/$(BOARD).*
	[ -f $(ARMTF_DIR)/Makefile ] && $(MAKE) -C $(ARMTF_DIR) PLAT=bm1000 BAIKAL_TARGET=$(BE_TARGET) realclean || true

distclean: clean
	rm -rf $(UEFI_DIR) $(ARMTF_DIR) $(KBUILD_DIR) $(TOP_DIR)/kernel basetools img

.PHONY: dtb uefi arm-tf bootrom
