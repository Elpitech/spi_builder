#!/bin/bash 

if [ -z "${BIOS_WORKSPACE}" ] ; then
	echo "BIOS_WORKSPACE must be set!"
	exit
fi

export WORKSPACE=${BIOS_WORKSPACE}
export EDK_TOOLS_PATH=${WORKSPACE}/edk2/BaseTools
export GCC5_AARCH64_PREFIX=${CROSS}
export ARCH=AARCH64
export PACKAGES_PATH=${WORKSPACE}/edk2:${WORKSPACE}/edk2-non-osi:${WORKSPACE}/edk2-platform-baikal
export PYTHON3_ENABLE=FALSE

cd ${WORKSPACE}
if ! [ -f edk2/Conf/target.txt ] ; then
	 . edk2/edksetup.sh --reconfig || exit
fi
NPROC=`nproc`
if [ $NPROC -gt 1 ] ; then
	 NPROC=`expr $NPROC - 1`
fi

. edk2/edksetup.sh || exit

if [[ ${SPI_FLASHER} -eq 1 ]]; then
	FLASH_IMAGE_C_INCLUDE=${WORKSPACE}/edk2-platform-baikal/Platform/Baikal/Application/SpiFlashImage/SpiFlashImageRaw.h
	echo "#define BOARD_FLASH_IMAGE {" > ${FLASH_IMAGE_C_INCLUDE}
	xxd -include < ${FLASH_IMG} >> ${FLASH_IMAGE_C_INCLUDE}
	sed --in-place 's/$/ \\/' ${FLASH_IMAGE_C_INCLUDE}
	echo "}" >> ${FLASH_IMAGE_C_INCLUDE}
fi

echo "Running build -p ${UEFI_PLATFORM} -b ${BUILD_TYPE} -a ${ARCH} -t GCC5 -n ${NPROC} ${UEFI_FLAGS}"
build -p ${UEFI_PLATFORM} -b ${BUILD_TYPE} -a ${ARCH} -t GCC5 -n ${NPROC} ${UEFI_FLAGS} || exit
echo "UEFI build: Done"
