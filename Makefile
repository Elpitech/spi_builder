# The kernel sources are used to build DTB. The sources are at:
# git@github.com:elpitech/kernel.git
KDIR ?= $(HOME)/gitlab/baikal-m/kernel

# You can use a generic ARM64 compiler, or the one from Baikal SDK
CROSS := $(HOME)/toolchains/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-

ARM_TF_GIT := git@gitlab.elp:baikal-m/arm-tf.git
# ARM_TF_GIT := git@github.com:elpitech/arm-tf.git

# For older UEFI from SDK 4.4 use our sources
OLD_EDK2_GIT := git@gitlab.elp:baikal-m/edk2.git -b 4.4-tp
# OLD_EDK2_GIT := git@github.com:elpitech/edk2.git -b 4.4-tp

# Newer UEFI in SDK 5.1 is coupled with the upstream code. Only
# platform-specific part comes from our sources.
NEW_EDK2_GIT := http://github.com/tianocore/edk2.git
NEW_EDK2_NON_OSI_GIT := https://github.com/tianocore/edk2-non-osi.git
NEW_EDK2_PLATFORM_SPECIFIC_GIT := git@gitlab.elp:baikal-m/edk2-platform-baikal.git
#NEW_EDK2_PLATFORM_SPECIFIC_GIT := git@github.com:elpitech/edk2-platform-baikal.git

# SDK_VER = 4.4
SDK_VER ?= 5.1
SDK_REV = 1
BOARD ?= mitx-d
PLAT = bm1000

ifeq ($(BOARD),mitx)
	BE_TARGET = mitx
	BOARD_VER = 0
else ifeq ($(BOARD),mitx-d)
	BE_TARGET = mitx
	BOARD_VER = 2
#	DUAL_FLASH ?= yes
else ifeq ($(BOARD),mitx-d-lvds)
	BE_TARGET = mitx
	BOARD_VER = 2
#	DUAL_FLASH ?= yes
else ifeq ($(BOARD),e107)
	BE_TARGET = mitx
	BOARD_VER = 1
endif

DUAL_FLASH ?= no
UEFI_BUILD_TYPE ?= RELEASE
#UEFI_BUILD_TYPE = DEBUG
ARMTF_DEBUG ?= 0

SCP_BLOB = ./prebuilts/$(SDK_VER)/$(BE_TARGET).scp.flash.bin

ARCH = arm64
NCPU := $(shell nproc)

IMG_DIR := $(CURDIR)/img
BIOS_WORKSPACE := $(CURDIR)/workspace
ARMTF_DIR := $(BIOS_WORKSPACE)/arm-tf
DTB_DIR := $(BIOS_WORKSPACE)/build

TARGET_CFG = $(BE_TARGET)_defconfig
TARGET_DTB = baikal/bm-$(BOARD).dtb
KERNEL_FLAGS = O=$(DTB_DIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) -C $(KDIR)

ifeq ($(SDK_VER),4.4)
else
	UEFI_FLAGS = -DFIRMWARE_VERSION_STRING=$(SDK_VER) -DFIRMWARE_REVISION=$(SDK_REV)
	UEFI_FLAGS += -DFIRMWARE_VENDOR=\"Edelweiss\"
endif
ifeq ($(BE_TARGET),mitx)
	UEFI_FLAGS += -DBE_MITX=TRUE -DBOARD_VER=$(BOARD_VER)
endif

ifeq ($(ARMTF_DEBUG),0)
ARMTF_BUILD_TYPE=release
else
ARMTF_BUILD_TYPE=debug
endif

ARMTF_BUILD_DIR = $(ARMTF_DIR)/build/$(PLAT)/$(ARMTF_BUILD_TYPE)
BL1_BIN = $(ARMTF_BUILD_DIR)/bl1.bin
FIP_BIN = $(ARMTF_BUILD_DIR)/fip.bin

all: setup bootrom

setup:
ifeq ($(SDK_VER),4.4)
	if [ ! -d $(BIOS_WORKSPACE) ]; then \
	mkdir $(BIOS_WORKSPACE); \
	cd $(BIOS_WORKSPACE); \
	git clone $(ARM_TF_GIT) -b v2.3-tp; \
	git clone $(OLD_EDK2_GIT); \
	cd $(CURDIR); \
	fi
else
	if [ ! -d $(BIOS_WORKSPACE) ]; then \
	mkdir $(BIOS_WORKSPACE); \
	cd $(BIOS_WORKSPACE); \
	git clone $(ARM_TF_GIT) -b v2.4-tp; \
	git clone $(NEW_EDK2_GIT); \
	git clone $(NEW_EDK2_NON_OSI_GIT); \
	git clone $(NEW_EDK2_PLATFORM_SPECIFIC_GIT); \
	cd $(BIOS_WORKSPACE)/edk2; \
	git checkout 06dc822d045; \
	git submodule update --init; \
	cd $(CURDIR); \
	fi
endif

# Note: BaseTools cannot be built in parallel.
basetools:
	SDK_VER=$(SDK_VER) BIOS_WORKSPACE=$(BIOS_WORKSPACE) ./buildbasetools.sh

uefi $(IMG_DIR)/$(BOARD).efi.fd: basetools
	mkdir -p img
	rm -f $(IMG_DIR)/$(BOARD).efi.fd
	rm -rf $(BIOS_WORKSPACE)/Build
	SDK_VER=$(SDK_VER) BIOS_WORKSPACE=$(BIOS_WORKSPACE) CROSS=$(CROSS) BUILD_TYPE=$(UEFI_BUILD_TYPE) UEFI_FLAGS="$(UEFI_FLAGS)" ./builduefi.sh
ifeq ($(SDK_VER),4.4)
	cp $(BIOS_WORKSPACE)/edk2/Build/ArmBaikalBfkm-AARCH64/$(UEFI_BUILD_TYPE)_GCC6/FV/BFKM_EFI.fd $(IMG_DIR)/$(BOARD).efi.fd
else
	cp $(BIOS_WORKSPACE)/Build/Baikal/$(UEFI_BUILD_TYPE)_GCC5/FV/BAIKAL_EFI.fd $(IMG_DIR)/$(BOARD).efi.fd
endif

$(IMG_DIR)/$(BOARD).fip.bin: $(IMG_DIR)/$(BOARD).efi.fd
	rm -rf $(ARMTF_DIR)/build
	mkdir -p $(ARMTF_DIR)/build
	echo $(BOARD) > $(ARMTF_DIR)/build/subtarget
	$(MAKE) -j$(NCPU) CROSS_COMPILE=$(CROSS) BE_TARGET=$(BE_TARGET) BOARD_VER=$(BOARD_VER) DUAL_FLASH=$(DUAL_FLASH) PLAT=$(PLAT) DEBUG=$(ARMTF_DEBUG) LOAD_IMAGE_V2=0 -C $(ARMTF_DIR) all
	$(MAKE) -j$(NCPU) CROSS_COMPILE=$(CROSS) BE_TARGET=$(BE_TARGET) BOARD_VER=$(BOARD_VER) DUAL_FLASH=$(DUAL_FLASH) PLAT=$(PLAT) DEBUG=$(ARMTF_DEBUG) LOAD_IMAGE_V2=0 BL33=$(IMG_DIR)/$(BOARD).efi.fd -C $(ARMTF_DIR) fip
	cp $(FIP_BIN) $(IMG_DIR)/$(BOARD).fip.bin
	cp $(BL1_BIN) $(IMG_DIR)/$(BOARD).bl1.bin

bootrom: $(IMG_DIR)/$(BOARD).fip.bin $(IMG_DIR)/$(BOARD).dtb
	IMG_DIR=$(IMG_DIR) BOARD=$(BOARD) SCP_BLOB=$(SCP_BLOB) DUAL_FLASH=$(DUAL_FLASH) ./genrom.sh

dtb $(IMG_DIR)/$(BOARD).dtb: 
	mkdir -p $(DTB_DIR)
	$(MAKE) -j$(NCPU) $(KERNEL_FLAGS) $(TARGET_CFG)
	$(MAKE) -j$(NCPU) $(KERNEL_FLAGS) $(TARGET_DTB)
	cp $(DTB_DIR)/arch/$(ARCH)/boot/dts/$(TARGET_DTB) $(IMG_DIR)/$(BOARD).dtb

clean:
	rm -rf $(DTB_DIR)
	rm -rf $(BIOS_WORKSPACE)/Build
	rm -rf $(BIOS_WORKSPACE)/edk2/Build
	rm -rf $(IMG_DIR)/$(BOARD).*
	$(MAKE) -C $(ARMTF_DIR) PLAT=bm1000 BE_TARGET=$(BE_TARGET) realclean

distclean: clean
	rm -rf $(BIOS_WORKSPACE)

.PHONY: dtb uefi bootrom
