#!/bin/bash

START_TIME=$(date +"%s")

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 board"
    exit 1
fi
SYNCLOUD_BOARD=$1
echo "========== ${SYNCLOUD_BOARD} =========="

if [ ! -f "syncloud-rootfs.tar.gz" ]; then
    echo "rootfs is not ready, run 'sudo ./rootfs.sh'"
    exit 1
elae
    echo "syncloud-rootfs.tar.gz is here"
fi

BOOT_ZIP=${SYNCLOUD_BOARD}.tar.gz
if [ ! -f ${BOOT_ZIP} ]; then
  echo "${BOOT_ZIP} is not ready, run 'sudo ./extract ${SYNCLOUD_BOARD}'"
  exit 1
else
  echo "$BOOT_ZIP is here"
fi

tar xzf syncloud-rootfs.tar.gz

#Fix debconf frontend warnings
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBCONF_FRONTEND=noninteractive
export DEBIAN_FRONTEND=noninteractive
export TMPDIR=/tmp
export TMP=/tmp

RESIZE_PARTITION_ON_FIRST_BOOT=true
SYNCLOUD_IMAGE=syncloud-${SYNCLOUD_BOARD}.img

function cleanup {
    echo "cleanup"
    #if mount | grep ${SYNCLOUD_IMAGE}; then
        umount dst/root
    #fi
    losetup -a
    kpartx -v ${SYNCLOUD_IMAGE}
    echo "removing loop devices"
    kpartx -d ${SYNCLOUD_IMAGE}
}

cleanup

echo "installing dependencies"
sudo apt-get -y install dosfstools kpartx p7zip

echo "extracting boot"
rm -rf ${SYNCLOUD_BOARD}
tar xzf ${BOOT_ZIP}

echo "copying boot"
cp ${SYNCLOUD_BOARD}/boot ${SYNCLOUD_IMAGE}
BOOT_BYTES=$(wc -c "${SYNCLOUD_IMAGE}" | cut -f 1 -d ' ')
BOOT_SECTORS=$(( ${BOOT_BYTES} / 512 ))
echo "boot sectors: ${BOOT_SECTORS}"

DD_CHUNK_SIZE_MB=10
DD_CHUNK_COUNT=200
ROOTFS_SIZE_BYTES=$(( ${DD_CHUNK_SIZE_MB} * 1024 * 1024 * ${DD_CHUNK_COUNT} ))
echo "appending $(( ${ROOTFS_SIZE_BYTES} / 1024 / 1024 )) MB"
dd if=/dev/zero bs=${DD_CHUNK_SIZE_MB}M count=${DD_CHUNK_COUNT} >> ${SYNCLOUD_IMAGE}
ROOTFS_START_SECTOR=$(( ${BOOT_SECTORS} + 1  ))
ROOTFS_SECTORS=$(( ${ROOTFS_SIZE_BYTES} / 512 ))
ROOTFS_END_SECTOR=$(( ${ROOTFS_START_SECTOR} + ${ROOTFS_SECTORS} - 2 ))
echo "extending defining second partition (${ROOTFS_START_SECTOR} - ${ROOTFS_END_SECTOR}) sectors"
echo "
p
d
2
p
n
p
2
${ROOTFS_START_SECTOR}
${ROOTFS_END_SECTOR}
p
w
q
" | fdisk ${SYNCLOUD_IMAGE}

kpartx -a ${SYNCLOUD_IMAGE}
LOOP=$(kpartx -l ${SYNCLOUD_IMAGE} | head -1 | cut -d ' ' -f1 | cut -c1-5)
rm -rf dst
mkdir -p dst/root

mkfs.ext4 /dev/mapper/${LOOP}p2
mount /dev/mapper/${LOOP}p2 dst/root

echo "copying rootfs"
cp -rp rootfs/* dst/root/
cp -rp ${SYNCLOUD_BOARD}/root/* dst/root/

echo "setting resize on boot flag"
if [ "$RESIZE_PARTITION_ON_FIRST_BOOT" = true ] ; then
    touch dst/root/var/lib/resize_partition_flag
fi

echo "setting hostname"
echo ${SYNCLOUD_BOARD} > dst/root/etc/hostname

echo "setting hosts"
echo "::1 localhost ip6-localhost ip6-loopback" > dst/root/etc/hosts
echo "fe00::0 ip6-localnet" >> dst/root/etc/hosts
echo "ff00::0 ip6-mcastprefix" >> dst/root/etc/hosts
echo "ff02::1 ip6-allnodes" >> dst/root/etc/hosts
echo "ff02::2 ip6-allrouters" >> dst/root/etc/hosts
echo "127.0.0.1 localhost" >> dst/root/etc/hosts

sync

cleanup

xz -0 ${SYNCLOUD_IMAGE}

FINISH_TIME=$(date +"%s")
BUILD_TIME=$(($FINISH_TIME-$START_TIME))
echo "image: ${SYNCLOUD_IMAGE}"
echo "Build time: $(($BUILD_TIME / 60)) min"
