#!/bin/bash 
# Make FLASH_IMG: concatenate BL1, board IDs, DTB, FIP_BIN and reserve area for UEFI vars

FLASH_IMG=${IMG_DIR}/${BOARD}.flash.img
BL1_RESERVED_SIZE=$((4 * 65536)) #0x40000
DTB_SIZE=$(( 1 * 65536 ))
UEFI_VARS_SIZE=$(( 12 * 65536 ))
LINUX_PART_START=$(( 8 * 1024 * 1024 ))
FIP_MAX_SIZE=$(($LINUX_PART_START - ($DTB_SIZE) - ($UEFI_VARS_SIZE) - ($BL1_RESERVED_SIZE)))
FIP_BIN=${IMG_DIR}/${BOARD}.fip.bin

cp -f ${IMG_DIR}/${BOARD}.bl1.bin ${FLASH_IMG} || exit
truncate --no-create --size=${BL1_RESERVED_SIZE} ${FLASH_IMG} || exit
cat ${IMG_DIR}/${BOARD}.dtb >> ${FLASH_IMG} || exit
truncate --no-create --size=$(($BL1_RESERVED_SIZE + $DTB_SIZE)) ${FLASH_IMG} || exit
truncate --no-create --size=$(($BL1_RESERVED_SIZE + $DTB_SIZE + $UEFI_VARS_SIZE)) ${FLASH_IMG} || exit
cat ${FIP_BIN} >> ${FLASH_IMG} || exit

if [[ ${DUAL_FLASH} = 'no' ]]; then
	# add 512 KB SCP image; 0.5 + 8 + 23.5 = 32 MB total flash size
	cat ${SCP_BLOB} ${FLASH_IMG} > ${IMG_DIR}/${BOARD}.full.img
	dd if=/dev/zero bs=1M count=32 | tr "\000" "\377" > ${IMG_DIR}/${BOARD}.full.padded || exit
	dd if=${IMG_DIR}/${BOARD}.full.img of=${IMG_DIR}/${BOARD}.full.padded conv=notrunc || exit
	echo "00000000:0007ffff scp" > ${IMG_DIR}/${BOARD}.layout
	echo "00080000:000bffff bl1" >> ${IMG_DIR}/${BOARD}.layout
	echo "000c0000:000cffff dtb" >> ${IMG_DIR}/${BOARD}.layout
	echo "000d0000:0018ffff vars" >> ${IMG_DIR}/${BOARD}.layout
	echo "00190000:007fffff fip" >> ${IMG_DIR}/${BOARD}.layout
	echo "00800000:01ffffff fat" >> ${IMG_DIR}/${BOARD}.layout
else
	dd if=/dev/zero bs=1M count=32 | tr "\000" "\377" > ${IMG_DIR}/${BOARD}.full.padded || exit
	dd if=${FLASH_IMG} of=${IMG_DIR}/${BOARD}.full.padded conv=notrunc || exit
	echo "00000000:0003ffff bl1" > ${IMG_DIR}/${BOARD}.layout
	echo "00040000:0004ffff dtb" >> ${IMG_DIR}/${BOARD}.layout
	echo "00050000:0010ffff vars" >> ${IMG_DIR}/${BOARD}.layout
	echo "00110000:007fffff fip" >> ${IMG_DIR}/${BOARD}.layout
	echo "00800000:01ffffff fat" >> ${IMG_DIR}/${BOARD}.layout
fi

echo "BUILD BOOTROM: Done"
