#!/bin/sh

## Derived, if not outright copied, from:
## https://github.com/topjohnwu/Magisk/blob/master/scripts/boot_patch.sh
## Thanks!

get_abs_path() {
    echo "$(cd "$(dirname "${1}")" || exit 1; pwd)/$(basename "${1}")"
}
SCRIPT_RELATIVE_DIR=$(dirname "$(realpath "${0}")")

BOOTIMAGE="$(get_abs_path "${1}")"
MAGISK_VERSION="${2:-v25.2}"

echo "INFO: Downloading Magisk.."

MAGISK_DLOUTDIR="$("${SCRIPT_RELATIVE_DIR}/dl_magisk.sh" "${MAGISK_VERSION}")"

echo "INFO: Finished downloading Magisk."

export PATH="${MAGISK_DLOUTDIR}:${PATH}"

MAGISKBOOT="$(which magiskboot)"
TMPDIR="$(mktemp -d)/magiskpatch$$"
mkdir -p "${TMPDIR}" || {
    echo "Unable to create temporary directory at: ${TMPDIR}"
    echo "Please check permissions, and try again."
    exit 1
}

# Flags.

[ -z "${KEEPVERITY}" ] && KEEPVERITY=false
[ -z "${KEEPFORCEENCRYPT}" ] && KEEPFORCEENCRYPT=false
[ -z "${PATCHVBMETAFLAG}" ] && PATCHVBMETAFLAG=false
[ -z "${RECOVERYMODE}" ] && RECOVERYMODE=false

export KEEPVERITY
export KEEPFORCEENCRYPT
export PATCHVBMETAFLAG

if [ ! -e "${BOOTIMAGE}" ]; then
    echo "WARN: boot image (${BOOTIMAGE}) does NOT exist!"
    exit 1
fi

# cd to build dir
cd "${TMPDIR}" || {
    echo "Unable to change directory to: ${TMPDIR}."
    exit 1
}

echo "INFO: Extracting boot image.."
"${MAGISKBOOT}" unpack "${BOOTIMAGE}"

case "${?}" in
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
    "${MAGISKBOOT}" cpio "./ramdisk.cpio" "test"
    RAMDISK_STATUS="${?}"
else
    RAMDISK_STATUS=0
fi

case $((RAMDISK_STATUS & 3)) in
    0)
        echo "INFO: Stock boot image detected."
        SHA1=$("${MAGISKBOOT}" sha1 "${BOOTIMAGE}" 2>/dev/null)
        cat "${BOOTIMAGE}" > ./stock_boot.img
        cp -af ./ramdisk.cpio ./ramdisk.cpio.orig 2>/dev/null
        ;;
    1)
        echo "INFO: Boot image patched by Magisk."
        SHA1=$("${MAGISKBOOT}" cpio ramdisk.cpio sha1 2>/dev/null)
        "${MAGISKBOOT}" cpio ramdisk.cpio restore
        cp -af ramdisk.cpio ramdisk.cpio.orig
        rm -f stock_boot.img
        ;;
    *)
        echo "ERR: Boot image not supported; restore to stock."
        exit 1
        ;;
esac

{
    echo "KEEPVERITY=${KEEPVERITY}"
    echo "KEEPFORCEENCRYPT=${KEEPFORCEENCRYPT}"
    echo "PATCHVBMETAFLAG=${PATCHVBMETAFLAG}"
    echo "RECOVERYMODE=${RECOVERYMODE}"
} >> config

[ -n "${SHA1}" ] && echo "SHA1=${SHA1}" >> config

echo "INFO: Compress Magisk binary.."
"${MAGISKBOOT}" compress=xz "${MAGISK_DLOUTDIR}"/magisk64 magisk64.xz

echo "INFO: Compress stub APK.."
"${MAGISKBOOT}" compress=xz "${MAGISK_DLOUTDIR}"/stub-release.apk stub.xz

echo "INFO: Create new ramdisk for root image.."
"${MAGISKBOOT}" cpio ramdisk.cpio \
"add 0750 init ${MAGISK_DLOUTDIR}/magiskinit" \
"mkdir 0750 overlay.d" \
"mkdir 0750 overlay.d/sbin" \
"add 0644 overlay.d/sbin/magisk64.xz magisk64.xz" \
"add 0644 overlay.d/sbin/stub.xz stub.xz" \
"patch" \
"backup ramdisk.cpio.orig" \
"mkdir 000 .backup" \
"add 000 .backup/.magisk config"

rm -f ramdisk.cpio.orig config magisk*.xz stub.xz

# DTB patches

for dt in dtb kernel_dtb extra; do
  if [ -f "${dt}" ]; then
    if ! "${MAGISKBOOT}" dtb "${dt}" test; then
      echo "! Boot image ${dt} was patched by old (unsupported) Magisk"
    fi
    if "${MAGISKBOOT}" dtb "${dt}" patch; then
      echo "- Patch fstab in boot image ${dt}"
    fi
  fi
done

echo "INFO: Patching kernel.."
if [ -f kernel ]; then
  # Remove Samsung RKP
  ${MAGISKBOOT} hexpatch kernel \
  49010054011440B93FA00F71E9000054010840B93FA00F7189000054001840B91FA00F7188010054 \
  A1020054011440B93FA00F7140020054010840B93FA00F71E0010054001840B91FA00F7181010054

  # Remove Samsung defex
  # Before: [mov w2, #-221]   (-__NR_execve)
  # After:  [mov w2, #-32768]
  ${MAGISKBOOT} hexpatch kernel 821B8012 E2FF8F12

  # Force kernel to load rootfs
  # skip_initramfs -> want_initramfs
  ${MAGISKBOOT} hexpatch kernel \
  736B69705F696E697472616D667300 \
  77616E745F696E697472616D667300
fi

echo "INFO: Repacking kernel image.."
"${MAGISKBOOT}" repack "${BOOTIMAGE}"


# Check `/out` exits, if not, write to local dir.

if [ -d "/out" ]; then
    echo "Copy root-boot image to /out/root-boot.img"
    cp "${TMPDIR}"/new-boot.img /out/root-boot.img
else 
    echo "Copy root-boot image to $(dirname "$BOOTIMAGE")/root-boot.img"
    cp "${TMPDIR}"/new-boot.img "$(dirname "$BOOTIMAGE")/root-boot.img"
fi


echo "Cleaning up.."
rm -rf "${MAGISK_DLOUTDIR}" "${TMPDIR}"

echo "Finished."

exit
