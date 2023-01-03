#!/bin/sh

SCRIPT_RELATIVE_DIR=$(dirname $(realpath "${0}"))

MAGISK_DLTMPDIR="$(mktemp -d)/magiskdl${$}"
MAGISK_DLOUTDIR="$(mktemp -d)/magiskdltmp${$}"
REPO="topjohnwu/Magisk"
VERSION="${2:-v25.2}"

mkdir -p "${MAGISK_DLTMPDIR}" && cd "${MAGISK_DLTMPDIR}" || {
    echo "Unable to create temporary download directory at: ${MAGISK_DLTMPDIR}."
    echo "Check permissions and try again."
    exit 1
}

mkdir -p "${MAGISK_DLOUTDIR}" || {
    echo "Unable to create final download directory at: ${MAGISK_DLOUTDIR}."
    exit 1
}

[ ! -e "$(command -v unzip)" ] && {
    echo "\`unzip\` not available on \$PATH."
    echo "Please install the \`unzip\` package."
    exit 1
}
[ ! -e "$(command -v curl)" ] && {
    echo "\`curl\` not available on \$PATH."
    echo "Please install the \`curl\` package."
    exit 1
}

[ ! -d "${MAGISK_DLTMPDIR}" ] && exit 1
[ ! -d "${MAGISK_DLOUTDIR}" ] && exit 1

curl -Lso Magisk-"${VERSION}".apk https://github.com/"${REPO}"/releases/download/"${VERSION}"/Magisk-"${VERSION}".apk || {
    echo "Unable to download Magisk-${VERSION}.apk from GitHub."
    exit 1
}
curl -Lso "${MAGISK_DLOUTDIR}"/stub-release.apk https://github.com/"${REPO}"/releases/download/"${VERSION}"/stub-release.apk || {
    echo "Unable to download the stub APK for Magisk-${VERSION} from GitHub."
    exit 1
}

mkdir -p extract && cd extract || {
    echo "Unable to create and change directory to temporary ZIP extraction directory."
    exit 1
}

unzip -q "${MAGISK_DLTMPDIR}"/Magisk-"${VERSION}".apk

cp lib/x86/libmagiskboot.so "${MAGISK_DLOUTDIR}"/magiskboot
cp lib/arm64-v8a/libmagisk64.so "${MAGISK_DLOUTDIR}"/magisk64
cp lib/arm64-v8a/libmagiskinit.so "${MAGISK_DLOUTDIR}"/magiskinit

chmod +x "${MAGISK_DLOUTDIR}"/*

rm -rf "${MAGISK_DLTMPDIR}"

echo "${MAGISK_DLOUTDIR}"

exit
