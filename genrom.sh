#!/bin/bash 
# Make FLASH_IMG: concatenate BL1, board IDs, DTB, FIP_BIN and reserve area for UEFI vars

BL1_RESERVED_SIZE=$((4 * 65536)) #0x40000
DTB_SIZE=$(( 4 * 65536 ))
TRF_OFFS=$((2 * 65536))
UEFI_VARS_SIZE=$(( 12 * 65536 ))
LINUX_PART_START=$(( 8 * 1024 * 1024 ))
FIP_MAX_SIZE=$(($LINUX_PART_START - ($DTB_SIZE) - ($UEFI_VARS_SIZE) - ($BL1_RESERVED_SIZE)))
FIP_BIN=${IMG_DIR}/${BOARD}.fip.bin
TRF_IMG=${IMG_DIR}/../prebuilts/bs1000-ddr-trainfware.bin
if [ -d .git ] ; then
	RELTAG=$(git describe --tags)
else
	RELTAG=$(date +%Y%m%d)
fi

case "${BOARD}" in
    et151-lvds)
        MB="ET151-MB-1.1"
        ;;
    et151-dp)
        MB="ET151-MB-2-Rev1"
        ;;
    et121)
        MB="ET121-MB-Rev1"
        ;;
    et141)
        MB="ET141-MB-Rev1"
        ;;
    et101-lvds)
        MB="ET101-MB-1.1-Rev1.1"
        ;;
    et101-v2-lvds)
        MB="ET101-MB-1.1-Rev2"
        ;;
    et101-v2-dp)
        MB="ET101-MB-1.2-Rev2"
        ;;
    mitx-d)
        MB="TF307-MB-S-D-Rev4.0"
        ;;
    em407)
        MB="EM407"
        ;;
    et111)
        MB="ET111"
        ;;
    et113)
        MB="ET113-MB-A"
        ;;
    *)
        MB="${BOARD}"
        ;;
esac

if [ -n "${MAX_FREQ}" ] ; then
	SUFFIX=${SDK_VER}-${MAX_FREQ}_${RELTAG}
else
	SUFFIX=${SDK_VER}_${RELTAG}
fi
FLASH_IMG=${REL_DIR}/${BOARD}/${MB}_${SUFFIX}.flash.img
PADDED=${REL_DIR}/${BOARD}/${MB}_${SUFFIX}.full.padded
LAYOUT=${IMG_DIR}/${MB}.layout

mkdir -p ${REL_DIR}/${BOARD}
cp -f ${IMG_DIR}/${BOARD}.bl1.bin ${FLASH_IMG} || exit
chmod a-x ${FLASH_IMG}
truncate --no-create --size=${BL1_RESERVED_SIZE} ${FLASH_IMG} || exit
cat ${IMG_DIR}/${BOARD}.dtb >> ${FLASH_IMG} || exit
if [ "${PLAT}" = "bs1000" ] ; then
	echo 1fc00 01 11 21 31 41 51 61 71 81 91 a1 b1 | xxd -r  - ${FLASH_IMG}
	truncate --no-create --size=$(($BL1_RESERVED_SIZE + $TRF_OFFS)) ${FLASH_IMG} || exit
	cat ${TRF_IMG} >> ${FLASH_IMG}
fi
truncate --no-create --size=$(($BL1_RESERVED_SIZE + $DTB_SIZE + $UEFI_VARS_SIZE)) ${FLASH_IMG} || exit
cat ${FIP_BIN} >> ${FLASH_IMG} || exit

dd if=/dev/zero bs=1M count=32 | tr "\000" "\377" > ${PADDED} || exit
if [ ${DUAL_FLASH} = 'no' ]; then
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
	dd if=${FLASH_IMG} of=${PADDED} conv=notrunc || exit
	echo "00000000:0003ffff bl1" > ${LAYOUT}
	echo "00040000:0007ffff dtb" >> ${LAYOUT}
	echo "00080000:000bffff vars" >> ${LAYOUT}
	echo "000c0000:007fffff fip" >> ${LAYOUT}
	echo "00800000:01ffffff fat" >> ${LAYOUT}
fi

echo "BUILD BOOTROM: Done"
