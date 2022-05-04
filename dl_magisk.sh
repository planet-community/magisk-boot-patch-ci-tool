#!/bin/sh

set -eu

DL_TMPDIR="$(mktemp -d)"
MAGISK_TMPDIR="${1}"
REPO="topjohnwu/Magisk"
VERSION="${2:-v24.3}"

[ ! -e "$(which unzip)" ] && exit 1
[ ! -e "$(which curl)" ] && exit 1
[ ! -d "${DL_TMPDIR}" ] && exit 1
[ ! -d "${MAGISK_TMPDIR}" ] && exit 1

cd "${DL_TMPDIR}"

curl -Lso Magisk-"${VERSION}".apk https://github.com/"${REPO}"/releases/download/"${VERSION}"/Magisk-"${VERSION}".apk

mkdir -p extract && cd extract

unzip -q "${DL_TMPDIR}"/Magisk-"${VERSION}".apk

cp lib/x86_64/libmagiskboot.so "${MAGISK_TMPDIR}"/magiskboot

cp lib/arm64-v8a/libmagisk64.so "${MAGISK_TMPDIR}"/magisk64
cp lib/arm64-v8a/libmagiskinit.so "${MAGISK_TMPDIR}"/magiskinit

chmod +x "${MAGISK_TMPDIR}"/magisk*

exit
