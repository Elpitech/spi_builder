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

BOARD_IDS_SRC=${IMG_DIR}/${BOARD}.board.ids
if [ ! -f ${BOARD_IDS_SRC} ]; then
	while : ; do
		# Generate MAC addresses
		printf "BAIKALM_GMAC0_MACADDR=0x002658%.2x%.2x%.2x\n" $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) >  ${BOARD_IDS_SRC}
		printf "BAIKALM_GMAC1_MACADDR=0x002658%.2x%.2x%.2x\n" $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) >> ${BOARD_IDS_SRC}
		printf "BAIKALM_XGBE0_MACADDR=0x002658%.2x%.2x%.2x\n" $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) >> ${BOARD_IDS_SRC}
		printf "BAIKALM_XGBE1_MACADDR=0x002658%.2x%.2x%.2x\n" $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) $(( RANDOM % 0xff )) >> ${BOARD_IDS_SRC}
			# Check if there are no duplicate MAC addresses
		source ${BOARD_IDS_SRC}
		[[ $BAIKALM_GMAC0_MACADDR == $BAIKALM_GMAC1_MACADDR ]] || \
		[[ $BAIKALM_GMAC0_MACADDR == $BAIKALM_XGBE0_MACADDR ]] || \
		[[ $BAIKALM_GMAC0_MACADDR == $BAIKALM_XGBE1_MACADDR ]] || \
		[[ $BAIKALM_GMAC1_MACADDR == $BAIKALM_XGBE0_MACADDR ]] || \
		[[ $BAIKALM_GMAC1_MACADDR == $BAIKALM_XGBE1_MACADDR ]] || \
		[[ $BAIKALM_XGBE0_MACADDR == $BAIKALM_XGBE1_MACADDR ]] || \
		break
	done
fi

source ${BOARD_IDS_SRC}
echo "BL1 GMAC0 MAC address: ${BAIKALM_GMAC0_MACADDR}"
echo "BL1 GMAC1 MAC address: ${BAIKALM_GMAC1_MACADDR}"
echo "BL1 XGBE0 MAC address: ${BAIKALM_XGBE0_MACADDR}"
echo "BL1 XGBE1 MAC address: ${BAIKALM_XGBE1_MACADDR}"

BOARD_IDS_BIN=${IMG_DIR}/${BOARD}.board.ids.bin
printf "0:%.12x" $BAIKALM_GMAC0_MACADDR | xxd -groupsize4 -revert >  ${BOARD_IDS_BIN}
printf "0:%.12x" $BAIKALM_GMAC1_MACADDR | xxd -groupsize4 -revert >> ${BOARD_IDS_BIN}
printf "0:%.12x" $BAIKALM_XGBE0_MACADDR | xxd -groupsize4 -revert >> ${BOARD_IDS_BIN}
printf "0:%.12x" $BAIKALM_XGBE1_MACADDR | xxd -groupsize4 -revert >> ${BOARD_IDS_BIN}
hash crc32 || exit
printf "0:%.8x" "0x$(crc32 <(cat ${BOARD_IDS_BIN}))" | \
	sed -E 's/0:(..)(..)(..)(..)/0:\4\3\2\1/' | xxd -groupsize4 -revert >> ${BOARD_IDS_BIN}

BOARD_IDS_OFFSET=$(($( stat --format=%s ${FLASH_IMG} ) - 4 * 1024 ))
dd if=${BOARD_IDS_BIN} of=${FLASH_IMG} seek=${BOARD_IDS_OFFSET} obs=1 conv=notrunc || exit
rm ${BOARD_IDS_BIN}
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
