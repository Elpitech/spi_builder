#!/bin/bash 
# Make FLASH_IMG: concatenate BL1, board IDs, DTB, FIP_BIN and reserve area for UEFI vars

BL1_RESERVED_SIZE=$((4 * 65536)) #0x40000
DTB_SIZE=$(( 4 * 65536 ))
UEFI_VARS_SIZE=$(( 12 * 65536 ))
LINUX_PART_START=$(( 8 * 1024 * 1024 ))
FIP_MAX_SIZE=$(($LINUX_PART_START - ($DTB_SIZE) - ($UEFI_VARS_SIZE) - ($BL1_RESERVED_SIZE)))
FIP_BIN=${IMG_DIR}/${BOARD}.fip.bin
RELTAG=$(git describe --tags)

case "${BOARD}" in
    et151)
        MB="et151-mb-1.1-rev1"
        ;;
    et101-lvds)
        MB="et101-mb-1.1-rev1.1"
        ;;
    et101-v2-lvds)
        MB="et101-mb-1.1-rev2"
        ;;
    et101-v2-dp)
        MB="et101-mb-1.2-rev2"
        ;;
    mitx-d)
        MB="tf307-mb-s-d-rev4.0"
        ;;
    em407)
        MB="em407-com-express"
        ;;
    et111)
        MB="et111-laptop"
        ;;
    et113)
        MB="et113-mb-a-server"
        ;;
    et141)
        MB="et141-ramac-2x-pcie-dtx"
        ;;
    *)
        MB="${BOARD}"
        ;;
esac
FLASH_IMG=${REL_DIR}/${BOARD}/${MB}-${SDK_VER}-${MAX_FREQ}-${RELTAG}.flash.img
PADDED=${REL_DIR}/${BOARD}/${MB}-${SDK_VER}-${MAX_FREQ}-${RELTAG}.full.padded
LAYOUT=${IMG_DIR}/${MB}.layout

cp -f ${IMG_DIR}/${BOARD}.bl1.bin ${FLASH_IMG} || exit
chmod a-x ${FLASH_IMG}
truncate --no-create --size=${BL1_RESERVED_SIZE} ${FLASH_IMG} || exit
cat ${IMG_DIR}/${BOARD}.dtb >> ${FLASH_IMG} || exit
truncate --no-create --size=$(($BL1_RESERVED_SIZE + $DTB_SIZE)) ${FLASH_IMG} || exit
truncate --no-create --size=$(($BL1_RESERVED_SIZE + $DTB_SIZE + $UEFI_VARS_SIZE)) ${FLASH_IMG} || exit
cat ${FIP_BIN} >> ${FLASH_IMG} || exit

dd if=/dev/zero bs=1M count=32 | tr "\000" "\377" > ${PADDED} || exit
if [[ ${DUAL_FLASH} = 'no' ]]; then
	# add 512 KB SCP image; 0.5 + 8 + 23.5 = 32 MB total flash size
	cat ${SCP_BLOB} ${FLASH_IMG} > ${IMG_DIR}/${MB}.full.img
	dd if=${IMG_DIR}/${MB}.full.img of=${PADDED} conv=notrunc || exit
	echo "00000000:0007ffff scp" > ${LAYOUT}
	echo "00080000:000bffff bl1" >> ${LAYOUT}
	echo "000c0000:000fffff dtb" >> ${LAYOUT}
	echo "00100000:001bffff vars" >> ${LAYOUT}
	echo "001c0000:007fffff fip" >> ${LAYOUT}
	echo "00800000:01ffffff fat" >> ${LAYOUT}
else
	if [ "${PLAT}" = "bs1000" ] ; then
		echo 1fc00 0f 1f 2f 3f 4f 5f 6f 7f 8f 9f af bf | xxd -r  - ${FLASH_IMG}
	fi
	dd if=${FLASH_IMG} of=${PADDED} conv=notrunc || exit
	echo "00000000:0003ffff bl1" > ${LAYOUT}
	echo "00040000:0007ffff dtb" >> ${LAYOUT}
	echo "00080000:000bffff vars" >> ${LAYOUT}
	echo "000c0000:007fffff fip" >> ${LAYOUT}
	echo "00800000:01ffffff fat" >> ${LAYOUT}
fi

echo "BUILD BOOTROM: Done"
