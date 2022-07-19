#!/bin/bash 
# Make FLASH_IMG: concatenate BL1, board IDs, DTB, FIP_BIN and reserve area for UEFI vars

BL1_RESERVED_SIZE=$((4 * 65536)) #0x40000
DTB_SIZE=$(( 4 * 65536 ))
UEFI_VARS_SIZE=$(( 12 * 65536 ))
LINUX_PART_START=$(( 8 * 1024 * 1024 ))
FIP_MAX_SIZE=$(($LINUX_PART_START - ($DTB_SIZE) - ($UEFI_VARS_SIZE) - ($BL1_RESERVED_SIZE)))
FIP_BIN=./img/${BOARD}.fip.bin

case "${BOARD}" in
    et101-lvds)
        MB="et101-mb-1.1-rev1.1"
        ;;
    et101-v2-lvds)
        MB="et101-mb-1.1-rev2"
        ;;
    et101-v2-dp)
        MB="et101-mb-1.2-rev1.2"
        ;;
    *)
        MB="noname"
        ;;
esac
FLASH_IMG=./out/${MB}-${SDK_VER}-${MAX_FREQ}-${BDATE}.flash.img
PADDED=./out/${MB}-${SDK_VER}-${MAX_FREQ}-${BDATE}.full.padded
LAYOUT=./img/${MB}.layout

cp -f ./img/${BOARD}.bl1.bin ${FLASH_IMG} || exit
chmod a-x ${FLASH_IMG}
truncate --no-create --size=${BL1_RESERVED_SIZE} ${FLASH_IMG} || exit
cat ./img/${BOARD}.dtb >> ${FLASH_IMG} || exit
truncate --no-create --size=$(($BL1_RESERVED_SIZE + $DTB_SIZE)) ${FLASH_IMG} || exit
truncate --no-create --size=$(($BL1_RESERVED_SIZE + $DTB_SIZE + $UEFI_VARS_SIZE)) ${FLASH_IMG} || exit
cat ${FIP_BIN} >> ${FLASH_IMG} || exit

dd if=/dev/zero bs=1M count=32 | tr "\000" "\377" > ${PADDED} || exit
if [[ ${DUAL_FLASH} = 'no' ]]; then
	# add 512 KB SCP image; 0.5 + 8 + 23.5 = 32 MB total flash size
	cat ${SCP_BLOB} ${FLASH_IMG} > ./img/${MB}.full.img
	dd if=./img/${MB}.full.img of=${PADDED} conv=notrunc || exit
	echo "00000000:0007ffff scp" > ${LAYOUT}
	echo "00080000:000bffff bl1" >> ${LAYOUT}
	echo "000c0000:000fffff dtb" >> ${LAYOUT}
	echo "00100000:001bffff vars" >> ${LAYOUT}
	echo "001c0000:007fffff fip" >> ${LAYOUT}
	echo "00800000:01ffffff fat" >> ${LAYOUT}
else
	dd if=${FLASH_IMG} of=${PADDED} conv=notrunc || exit
	echo "00000000:0003ffff bl1" > ${LAYOUT}
	echo "00040000:0004ffff dtb" >> ${LAYOUT}
	echo "00050000:0010ffff vars" >> ${LAYOUT}
	echo "00110000:007fffff fip" >> ${LAYOUT}
	echo "00800000:01ffffff fat" >> ${LAYOUT}
fi

echo "BUILD BOOTROM: Done"
