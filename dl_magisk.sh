#!/bin/sh

SCRIPT_RELATIVE_DIR=$(dirname $(realpath "$0"))

DL_TMPDIR="$SCRIPT_RELATIVE_DIR/tmp/magiskdl$$"
MAGISK_DLOUTDIR="${1}"
REPO="topjohnwu/Magisk"
VERSION="${2:-v25.2}"

mkdir -p "${DL_TMPDIR}" && cd "${DL_TMPDIR}" || exit 1

[ ! -e "$(command -v unzip)" ] && exit 1
[ ! -e "$(command -v curl)" ] && exit 1
[ ! -d "${DL_TMPDIR}" ] && exit 1
[ ! -d "${MAGISK_DLOUTDIR}" ] && exit 1

curl -Lso Magisk-"${VERSION}".apk https://github.com/"${REPO}"/releases/download/"${VERSION}"/Magisk-"${VERSION}".apk
curl -Lso "${MAGISK_DLOUTDIR}"/stub-release.apk https://github.com/"${REPO}"/releases/download/"${VERSION}"/stub-release.apk

mkdir -p extract && cd extract

unzip -q "${DL_TMPDIR}"/Magisk-"${VERSION}".apk

cp lib/x86/libmagiskboot.so "${MAGISK_DLOUTDIR}"/magiskboot

cp lib/arm64-v8a/libmagisk64.so "${MAGISK_DLOUTDIR}"/magisk64
cp lib/arm64-v8a/libmagiskinit.so "${MAGISK_DLOUTDIR}"/magiskinit

chmod 755 "${MAGISK_DLOUTDIR}"/*

rm -rf "${DL_TMPDIR}"

exit
