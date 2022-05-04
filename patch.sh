#!/bin/sh

get_abs_path() {
    echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

set -eu

MAGISK_TMP="/tmp/magiskdl$$"
MAGISK_VER="${2:-v24.3}"
mkdir -p "${MAGISK_TMP}"

echo "INFO: Downloading Magisk.."

./dl_magisk.sh "${MAGISK_TMP}" "${MAGISK_VER}"

echo "INFO: Finished downloading Magisk."

export PATH="${MAGISK_TMP}:${PATH}"

MAGISKBOOT="$(which magiskboot)"
TMPDIR="/tmp/magiskpatch$$"
mkdir -p "${TMPDIR}"

BOOTIMAGE="$(get_abs_path $1)"

if [ ! -e "$BOOTIMAGE" ]; then
    echo "WARN: boot image ($BOOTIMAGE) does NOT exist!"
    exit 1
fi

# cd to build dir
cd "$TMPDIR" || exit 1

echo "INFO: Extracting boot image.."
"$MAGISKBOOT" unpack "$BOOTIMAGE"

case "$?" in
    0)
        ;;
    1)
        echo "ERR: Unsupported image format or unknown."
        exit 1
        ;;
    2)
        echo "ERR: ChromeOS image, we don't handle those."
        exit 1
        ;;
    *)
        echo "ERR: Unable to unpack image. Corrupted?"
        exit 1
        ;;
esac


if [ -e "./ramdisk.cpio" ]; then
    "$MAGISKBOOT" cpio "./ramdisk.cpio" test
    RAMDISK_STATUS="$?"
else
    RAMDISK_STATUS=0
fi

case "${RAMDISK_STATUS}" in
    0)
        echo "INFO: Stock boot image detected."
        SHA1=$("$MAGISKBOOT" sha1 "$BOOTIMAGE" 2>/dev/null)
        cat "$BOOTIMAGE" > ./stock_boot.img
        cp -af ./ramdisk.cpio ./ramdisk.cpio.orig 2>/dev/null
        ;;
    1)
        echo "INFO: Boot image patched by Magisk."
        SHA1=$("$MAGISKBOOT" cpio ramdisk.cpio sha1 2>/dev/null)
        "$MAGISKBOOT" cpio ramdisk.cpio erstore
        cp -af ramdisk.cpio ramdisk.cpio.orig
        rm -f stock_boot.img
        ;;
    *)
        echo "ERR: Boot image not supported; restore to stock."
        exit 1
        ;;
esac

echo "INFO: Compress Magisk binary.."
"$MAGISKBOOT" compress=xz "${MAGISK_TMP}"/magisk64 magisk64.xz

echo "INFO: Create new ramdisk for root image.."
"$MAGISKBOOT" cpio ramdisk.cpio \
"add 0750 init ${MAGISK_TMP}/magiskinit" \
"mkdir 0750 overlay.d" \
"mkdir 0750 overlay.d/sbin" \
"add 0644 overlay.d/sbin/magisk64.xz magisk64.xz" \
"patch" \
"backup ramdisk.cpio.orig" \
"mkdir 000 .backup"

rm -f ramdisk.cpio.orig config magisk*.xz

echo "INFO: Patching kernel.."
"$MAGISKBOOT" hexpatch kernel \
  736B69705F696E697472616D667300 \
  77616E745F696E697472616D667300

echo "INFO: Repacking kernel image.."
"$MAGISKBOOT" repack "$BOOTIMAGE"

echo "Copy root-boot image to /tmp/root-boot.img"
cp -v ./new-boot.img /tmp/root-boot.img

cd /tmp

echo "Cleaning up.."
rm -rf "${MAGISK_TMP}" "${TMPDIR}"

echo "Finished."
exit
