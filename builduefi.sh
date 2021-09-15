#!/bin/bash -x

dpkg -l | grep -q acpica-tools || exit

if [ -z "${BIOS_WORKSPACE}" ] ; then
	echo "BIOS_WORKSPACE must be set!"
	exit
fi

NPROC=`nproc`
if [ $NPROC -gt 1 ] ; then
	NPROC=`expr $NPROC - 1`
fi

export PYTHON3_ENABLE=FALSE

case "${SDK_VER}" in
    4.4)
		UEFI_PLATFORM=ArmBaikalPkg/ArmBaikalBfkm.dsc 
		export WORKSPACE= # for Jenkins' workspace to not interfere with UEFI's one
		export EDK_TOOLS_PATH=${BIOS_WORKSPACE}/edk2/BaseTools
		export GCC6_AARCH64_PREFIX=${CROSS}
		cd ${BIOS_WORKSPACE}/edk2
		if ! [ -f ./Conf/target.txt ] ; then
			mkdir -p ${BIOS_WORKSPACE}/edk2/Conf
			. ./edksetup.sh --reconfig || exit
		else
			. ./edksetup.sh || exit
		fi
		build -p ${UEFI_PLATFORM} -b ${BUILD_TYPE} ${UEFI_FLAGS} || exit
		;;
    5.1)
		UEFI_PLATFORM=Platform/Baikal/Baikal.dsc 
		export WORKSPACE=${BIOS_WORKSPACE}
		export EDK_TOOLS_PATH=${BIOS_WORKSPACE}/edk2/BaseTools
		export GCC5_AARCH64_PREFIX=${CROSS}
		export ARCH=AARCH64
		export PACKAGES_PATH=${WORKSPACE}/edk2:${WORKSPACE}/edk2-non-osi:${WORKSPACE}/edk2-platform-baikal
		cd ${BIOS_WORKSPACE}
		if ! [ -f edk2/Conf/target.txt ] ; then
			. edk2/edksetup.sh --reconfig || exit
		else
			. edk2/edksetup.sh || exit 1
		fi
		build -p ${UEFI_PLATFORM} -b ${BUILD_TYPE} -a ${ARCH} -t GCC5 -n ${NPROC} ${UEFI_FLAGS} || exit
		;;
	5.2)
		UEFI_PLATFORM=Platform/Baikal/BM1000Rdb/BM1000Rdb.dsc
		export WORKSPACE=${BIOS_WORKSPACE}
		export EDK_TOOLS_PATH=${BIOS_WORKSPACE}/edk2/BaseTools
		export GCC5_AARCH64_PREFIX=${CROSS}
		export ARCH=AARCH64
		export PACKAGES_PATH=${WORKSPACE}/edk2:${WORKSPACE}/edk2-non-osi:${WORKSPACE}/edk2-platform-baikal
		cd ${BIOS_WORKSPACE}
		if ! [ -f edk2/Conf/target.txt ] ; then
			. edk2/edksetup.sh --reconfig || exit
		else
			. edk2/edksetup.sh || exit
		fi
		build -p ${UEFI_PLATFORM} -b ${BUILD_TYPE} -a ${ARCH} -t GCC5 -n ${NPROC} ${UEFI_FLAGS} || exit
		;;
esac

echo "UEFI build: Done"
exit 0
