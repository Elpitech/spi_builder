#!/bin/bash

if [ -n "$1" ]; then
	TARGET=$1
	shift
fi
rm -f basetools
TOPDIR=`pwd`
cd ${BIOS_WORKSPACE}
export WORKSPACE=${BIOS_WORKSPACE}
export EDK_TOOLS_PATH=${WORKSPACE}/edk2/BaseTools
export PACKAGES_PATH=${WORKSPACE}/edk2:${WORKSPACE}/edk2-non-osi:${WORKSPACE}/edk2-platform-baikal
. edk2/edksetup.sh || exit
make -C edk2/BaseTools $TARGET && touch ${TOPDIR}/basetools
