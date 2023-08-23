CROSS ?= aarch64-linux-gnu-
BOARD ?= et101-v2-dp
#BOARD ?= et101-v2-lvds
SPI_FLASHER ?= 0
#MAX_FREQ ?= 2133
#MAX_FREQ ?= 2400
BAIKAL_DDR_CUSTOM_CLOCK_FREQ = $(shell expr $(MAX_FREQ) / 2)

SDK_VER := 5.8
SDK_REV = 0x58
PLAT = bm1000

# End of user configurable parameters

TOP_DIR := $(shell pwd)
ARMTF_DIR := $(TOP_DIR)/arm-tf
UEFI_DIR := $(TOP_DIR)/uefi
KBUILD_DIR := $(TOP_DIR)/kbuild
KERN_DIR := $(TOP_DIR)/kernel

ifeq ($(BOARD),mitx)
	BE_TARGET = elp_bm
	BOARD_VER = 0
else ifeq ($(BOARD),mitx-d)
	BE_TARGET = elp_bm
	BOARD_VER = 2
else ifeq ($(BOARD),e107)
	BE_TARGET = elp_bm
	BOARD_VER = 1
else ifneq ($(filter et101-%,$(BOARD)),)
	BE_TARGET = elp_bm
	BOARD_VER = 2
else ifneq ($(filter et151-%,$(BOARD)),)
	BE_TARGET = elp_bm
	BOARD_VER = 7
else ifeq ($(BOARD),et141)
	BE_TARGET = elp_bm
	BOARD_VER = 5
else ifeq ($(BOARD),et121)
	BE_TARGET = elp_bm
	BOARD_VER = 5
else ifeq ($(BOARD),et161)
	BE_TARGET = elp_bm
	BOARD_VER = 5
else ifeq ($(BOARD),et111)
	BE_TARGET = elp_bm
	BOARD_VER = 3
else ifeq ($(BOARD),em407)
	BE_TARGET = elp_bm
	BOARD_VER = 4
else ifeq ($(BOARD),et113)
	BE_TARGET = elp_bs
	PLAT = bs1000
	DUAL_FLASH = yes
	BOARD_VER = 6
	MAX_FREQ =
endif

ARMTF_DEFS += "BAIKAL_DDR_CUSTOM_CLOCK_FREQ=$(BAIKAL_DDR_CUSTOM_CLOCK_FREQ)"
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
REL_DIR := $(CURDIR)/release

KERNEL_FLAGS = O=$(KBUILD_DIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) -C $(KERN_DIR)

ifneq ($(MAX_FREQ),)
	UEFI_FLAGS = -DFIRMWARE_VERSION_STRING=$(SDK_VER)-$(MAX_FREQ) -DFIRMWARE_REVISION=$(SDK_REV)
else
	UEFI_FLAGS = -DFIRMWARE_VERSION_STRING=$(SDK_VER) -DFIRMWARE_REVISION=$(SDK_REV)
endif
UEFI_FLAGS += -DFIRMWARE_VENDOR="Elpitech"
ifeq ($(BE_TARGET),elp_bm)
	TARGET_CFG = bm1000_defconfig
	TARGET_DTB = baikal/bm-$(BOARD).dtb
	UEFI_FLAGS += -DBAIKAL_ELP=TRUE -DBOARD_VER=$(BOARD_VER)
	UEFI_PLATFORM = Platform/Baikal/BM1000Rdb/BM1000Rdb.dsc
else
	TARGET_CFG = bm1000_defconfig
	TARGET_DTB = baikal/bs-$(BOARD).dtb
	UEFI_FLAGS += -DBAIKAL_ELP=TRUE -DBOARD_VER=$(BOARD_VER)
	UEFI_PLATFORM = Platform/Baikal/BS1000Rdb/BS1000Rdb.dsc
endif

ARMTF_BUILD_DIR = $(ARMTF_DIR)/build/$(PLAT)/$(ARMTF_BUILD_TYPE)
BL1_BIN = $(ARMTF_BUILD_DIR)/bl1.bin
FIP_BIN = $(ARMTF_BUILD_DIR)/fip.bin

all: setup bootrom

setup:
	mkdir -p $(IMG_DIR)
	mkdir -p $(REL_DIR)/${BOARD}
	mkdir -p $(KBUILD_DIR)
ifeq ($(SRC_ROOT),)
else
	[ -f $(ARMTF_DIR)/Makefile ] || (cp -pR $(SRC_ROOT)/arm-tf/* $(ARMTF_DIR))
	[ -f $(UEFI_DIR)/edk2/BaseTools ] || (cp -pR $(SRC_ROOT)/edk2/* $(UEFI_DIR)/edk2)
	[ -f $(UEFI_DIR)/edk2-non-osi/Emulator ] || (cp -pR $(SRC_ROOT)/edk2-non-osi/* $(UEFI_DIR)/edk2-non-osi)
	[ -f $(UEFI_DIR)/edk2-platform-baikal/Platform ] || (cp -pR $(SRC_ROOT)/edk2-platform-baikal/* $(UEFI_DIR)/edk2-platform-baikal)
	[ -f $(KERN_DIR)/Makefile ] || (cp -pR $(SRC_ROOT)/kernel/* $(KERN_DIR))
endif

modules:
	git submodule update --init --recursive

# Note: BaseTools cannot be built in parallel.
basetools:
	BIOS_WORKSPACE=$(UEFI_DIR) ./buildbasetools.sh

basetools-clean:
	BIOS_WORKSPACE=$(UEFI_DIR) ./buildbasetools.sh clean
	rm basetools

uefi $(IMG_DIR)/$(BOARD).efi.fd: basetools
	rm -f $(IMG_DIR)/$(BOARD).efi.fd
	rm -rf $(UEFI_DIR)/Build
	BIOS_WORKSPACE=$(UEFI_DIR) CROSS=$(CROSS) BUILD_TYPE=$(UEFI_BUILD_TYPE) UEFI_FLAGS="$(UEFI_FLAGS)" UEFI_PLATFORM="${UEFI_PLATFORM}" SPI_FLASHER=$(SPI_FLASHER) FLASH_IMG=${IMG_DIR}/${BOARD}.flash.img ./builduefi.sh
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
	SDK_VER=$(SDK_VER) BOARD=$(BOARD) SCP_BLOB=$(SCP_BLOB) DUAL_FLASH=$(DUAL_FLASH) MAX_FREQ=$(MAX_FREQ) PLAT=$(PLAT) IMG_DIR=$(IMG_DIR) REL_DIR=$(REL_DIR) ./genrom.sh

dtb $(IMG_DIR)/$(BOARD).dtb: 
	mkdir -p $(KBUILD_DIR)
	[ -f $(KBUILD_DIR)/Makefile ] || $(MAKE) $(KERNEL_FLAGS) $(TARGET_CFG)
	cd $(KBUILD_DIR) && $(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) $(TARGET_DTB)
	cp $(KBUILD_DIR)/arch/$(ARCH)/boot/dts/$(TARGET_DTB) $(IMG_DIR)/$(BOARD).dtb

clean: basetools-clean
	rm -rf $(KBUILD_DIR)
	rm -rf $(UEFI_DIR)/Build
	rm -f basetools
	rm -rf $(IMG_DIR) $(REL_DIR)
	[ -f $(ARMTF_DIR)/Makefile ] && $(MAKE) -C $(ARMTF_DIR) PLAT=bm1000 BAIKAL_TARGET=$(BE_TARGET) realclean || true

list:
	@echo "BOARD=et101-v2-lvds (et101-mb-1.1-rev2 or et101-mb-1.1-rev1.1)"
	@echo "BOARD=et101-v2-dp (et101-mb-1.2-rev2 or et101-mb-1.2-rev1.2)"
	@echo "BOARD=et113"
	@echo "BOARD=et121"
	@echo "BOARD=et141"
	@echo "BOARD=et151-lvds"
	@echo "BOARD=et151-dp"
	@echo "BOARD=em407"
	@echo "BOARD=e107"
	@echo "BOARD=et111 (notebook)"
	@echo "BOARD=mitx-d (tf307-mb-s-d-rev4.0)"
	@echo "BOARD=mitx"

.PHONY: dtb uefi arm-tf bootrom

#
# Repository rules
#

.PHONY: gitclean
gitclean:
	git clean -xfd
	git submodule foreach --recursive git clean -xfd

.PHONY: gitreset
gitreset:
	git reset --hard
	git submodule foreach --recursive git reset --hard

.PHONY: gitinit
gitinit:
	git submodule sync --recursive
	git submodule update --recursive --init --depth=1

.PHONY: gitfree
gitdrop:
	git submodule deinit --all

.PHONY: gitdist
gitdist:
	tar $(addprefix --exclude=,.git .gitignore .gitmodules .gitreview .azurepipelines build firmware-baikal-m.tar.xz) -cavf firmware-baikal-m.tar.xz .

