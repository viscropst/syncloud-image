#!/bin/bash -ex

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ "$1" == "" ]; then
    echo "Usage: $0 board"
    exit 1
fi

apt-get install -y kpartx pigz

SYNCLOUD_BOARD=$1

CPU_FREQUENCY_CONTROL=false
CPU_FREQUENCY_GOVERNOR=
CPU_FREQUENCY_MAX=
CPU_FREQUENCY_MIN=

SYNCLOUD_DISTR_URL="https://s3-us-west-2.amazonaws.com/syncloud-distributives"

if [[ ${SYNCLOUD_BOARD} == "raspberrypi2" ]]; then
  FILE_VERSION=2016-03-18
  IMAGE_FILE=/tmp/${FILE_VERSION}-raspbian-jessie-lite.img
  IMAGE_FILE_ZIP=${IMAGE_FILE}.zip
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/${FILE_VERSION}-raspbian-jessie-lite.zip -O $IMAGE_FILE_ZIP"
  UNZIP="unzip -o"
elif [[ ${SYNCLOUD_BOARD} == "raspberrypi3" ]]; then
  FILE_VERSION=2016-03-18
  IMAGE_FILE=/tmp/${FILE_VERSION}-raspbian-jessie-lite.img
  IMAGE_FILE_ZIP=${IMAGE_FILE}.zip
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/${FILE_VERSION}-raspbian-jessie-lite.zip -O $IMAGE_FILE_ZIP"
  UNZIP="unzip -o"
elif [[ ${SYNCLOUD_BOARD} == "beagleboneblack" ]]; then
  IMAGE_FILE=/tmp/${SYNCLOUD_BOARD}.img
  IMAGE_FILE_ZIP=${IMAGE_FILE}.xz
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/bone-debian-8.2-tester-2gb-armhf-2015-11-12-2gb.img.xz -O $IMAGE_FILE_ZIP"
  UNZIP=unxz
elif [[ ${SYNCLOUD_BOARD} == "cubieboard" ]]; then
  IMAGE_FILE="/tmp/Cubian-nano+headless-x1-a10.img"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.7z
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/Cubian-nano%2Bheadless-x1-a10.img.7z -O $IMAGE_FILE_ZIP"
  UNZIP="p7zip -d"
  CPU_FREQUENCY_CONTROL=true
  CPU_FREQUENCY_GOVERNOR=performance
  CPU_FREQUENCY_MAX=1056000
  CPU_FREQUENCY_MIN=648000
elif [[ ${SYNCLOUD_BOARD} == "cubieboard2" ]]; then
  IMAGE_FILE="/tmp/Cubian-nano+headless-x1-a20.img"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.7z
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/Cubian-nano%2Bheadless-x1-a20.img.7z -O $IMAGE_FILE_ZIP"
  UNZIP="p7zip -d"
  CPU_FREQUENCY_CONTROL=true
  CPU_FREQUENCY_GOVERNOR=performance
  CPU_FREQUENCY_MAX=1056000
  CPU_FREQUENCY_MIN=648000
elif [[ ${SYNCLOUD_BOARD} == "cubietruck" ]]; then
  IMAGE_FILE="/tmp/Cubian-nano+headless-x1-a20-cubietruck.img"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.7z
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/Cubian-nano%2Bheadless-x1-a20-cubietruck.img.7z -O $IMAGE_FILE_ZIP"
  UNZIP="p7zip -d"
  CPU_FREQUENCY_CONTROL=true
  CPU_FREQUENCY_GOVERNOR=performance
  CPU_FREQUENCY_MAX=1056000
  CPU_FREQUENCY_MIN=648000
elif [[ ${SYNCLOUD_BOARD} == "odroid-xu3and4" ]]; then
  IMAGE_FILE_NAME="ubuntu-16.04-mate-odroid-xu3-20160708.img"
  IMAGE_FILE="/tmp/${IMAGE_FILE_NAME}"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.xz
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/${IMAGE_FILE_NAME}.xz -O $IMAGE_FILE_ZIP"
  UNZIP=unxz
elif [[ ${SYNCLOUD_BOARD} == "odroid-c2" ]]; then
  IMAGE_FILE="/tmp/ubuntu64-16.04lts-mate-odroid-c2-20160226.img"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.xz
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/ubuntu64-16.04lts-mate-odroid-c2-20160226.img.xz -O $IMAGE_FILE_ZIP"
  UNZIP=unxz
elif [[ ${SYNCLOUD_BOARD} == "bananapim2" ]]; then
  IMAGE_FILE="/tmp/M2-raspberry-kernel3.3-LCD.img"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.zip
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/BPI-M2_Raspbian_V4.0_lcd.zip -O $IMAGE_FILE_ZIP"
  UNZIP=unzip
elif [[ ${SYNCLOUD_BOARD} == "bananapim1" ]]; then
  IMAGE_FILE="/tmp/BPI-M1_Debian_V2_beta.img"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.xz
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/BPI-M1_Debian_V2_beta.img.xz -O $IMAGE_FILE_ZIP"
  UNZIP=unxz
elif [[ ${SYNCLOUD_BOARD} == "bananapim3" ]]; then
  IMAGE_FILE_NAME="2016-05-15-debian-8-jessie-lite-bpi-m3-sd-emmc.img"
  IMAGE_FILE="/tmp/${IMAGE_FILE_NAME}"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.xz
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/${IMAGE_FILE_NAME}.xz -O $IMAGE_FILE_ZIP"
  UNZIP=unxz
elif [[ ${SYNCLOUD_BOARD} == "vbox" ]]; then
  IMAGE_FILE_NAME="debian-vbox-8gb.img"
  IMAGE_FILE="/tmp/$IMAGE_FILE_NAME"
  IMAGE_FILE_ZIP=${IMAGE_FILE}.xz
  DOWNLOAD_IMAGE="wget --progress=dot:giga ${SYNCLOUD_DISTR_URL}/$IMAGE_FILE_NAME.xz -O $IMAGE_FILE_ZIP"
  UNZIP=unxz
else
    echo "board is not supported: ${SYNCLOUD_BOARD}"
    exit 1
fi

PARTED_SECTOR_UNIT=s
DD_SECTOR_UNIT=b
OUTPUT=${SYNCLOUD_BOARD}

function cleanup {
    echo "cleanup"
    umount extract_rootfs || true
    umount boot || true
    kpartx -d ${IMAGE_FILE} || true
}

apt-get install unzip

cleanup

if [ ! -z "$TEAMCITY_VERSION" ]; then
  echo "running under TeamCity, cleaning base image cache"
  rm -rf ${IMAGE_FILE}
fi

if [ ! -f ${IMAGE_FILE} ]; then
  echo "Base image $IMAGE_FILE is not found, getting new one ..."
  ${DOWNLOAD_IMAGE}
  pushd .
  cd /tmp
  ls -la
  ${UNZIP} ${IMAGE_FILE_ZIP}
  popd
fi

echo "fdisk info:"
fdisk -l ${IMAGE_FILE}

echo "parted info:"
parted -sm ${IMAGE_FILE} print | tail -n +3

PARTITIONS=$(parted -sm ${IMAGE_FILE} print | tail -n +3 | wc -l)
if [ ${PARTITIONS} == 1 ]; then
    echo "single partition is not supported yet"
    exit 1
fi

BOOT_PARTITION_END_SECTOR=$(parted -sm ${IMAGE_FILE} unit ${PARTED_SECTOR_UNIT} print | grep "^1" | cut -d ':' -f3 | cut -d 's' -f1)
rm -rf ${OUTPUT}
mkdir ${OUTPUT}

echo "applying cpu frequency fix"
if [ "$CPU_FREQUENCY_CONTROL" = true ] ; then
    mkdir -p ${OUTPUT}/root/var/lib
    touch ${OUTPUT}/root/var/lib/cpu_frequency_control
    echo -n ${CPU_FREQUENCY_GOVERNOR} > ${OUTPUT}/root/var/lib/cpu_frequency_governor
    echo -n ${CPU_FREQUENCY_MAX} > ${OUTPUT}/root/var/lib/cpu_frequency_max
    echo -n ${CPU_FREQUENCY_MIN} > ${OUTPUT}/root/var/lib/cpu_frequency_min
fi

echo "fixing boot"

LOOP=$(kpartx -l ${IMAGE_FILE} | head -1 | cut -d ' ' -f1 | cut -c1-5)

echo "LOOP: ${LOOP}"

rm -rf boot
mkdir -p boot
kpartx -avs ${IMAGE_FILE}
kpartx -l ${IMAGE_FILE}

FS_TYPE=$(blkid -s TYPE -o value /dev/mapper/${LOOP}p1)
if [[ "${FS_TYPE}" == *"swap"*  ]]; then
    echo "not inspecting boot partition as it is: ${FS_TYPE}"
else
    echo "inspecting boot partition"

    mount /dev/mapper/${LOOP}p1 boot

    mount | grep boot

    ls -la boot/

    boot_ini=boot/boot.ini
    if [ -f ${boot_ini} ]; then
        cat ${boot_ini}
        sed -i 's#root=.* #root=/dev/mmcblk0p2 #g' ${boot_ini}
        cat ${boot_ini}
    fi

    rm -rf ${OUTPUT}-boot.tar.gz
    tar czf ${OUTPUT}-boot.tar.gz boot

    umount /dev/mapper/${LOOP}p1
    kpartx -d ${IMAGE_FILE} || true # not sure why this is not working sometimes
    rm -rf boot

fi

echo "extracting boot partition with boot loader"

dd if=${IMAGE_FILE} of=${OUTPUT}/boot bs=1${DD_SECTOR_UNIT} count=$(( ${BOOT_PARTITION_END_SECTOR} ))

echo "extracting kernel modules and firmware from rootfs"

rm -rf extract_rootfs
mkdir -p extract_rootfs
kpartx -avs ${IMAGE_FILE}
LOOP=$(kpartx -l ${IMAGE_FILE} | head -1 | cut -d ' ' -f1 | cut -c1-5)
blkid /dev/mapper/${LOOP}p2 -s UUID -o value > uuid
mount /dev/mapper/${LOOP}p2 extract_rootfs

mount | grep extract_rootfs

losetup -l

echo "source rootfs"
ls -la extract_rootfs/
ls -la extract_rootfs/lib/modules
ls -la extract_rootfs/boot

echo "target rootfs"
ls -la ${OUTPUT}

mkdir -p ${OUTPUT}/root/lib
cp -rp extract_rootfs/lib/firmware ${OUTPUT}/root/lib/firmware
cp -rp extract_rootfs/lib/modules ${OUTPUT}/root/lib/modules
cp uuid ${OUTPUT}/root/uuid
cp -rp extract_rootfs/boot ${OUTPUT}/root/boot
sync

cleanup

rm -rf ${OUTPUT}.tar.gz
tar -c --use-compress-program=pigz -f ${OUTPUT}.tar.gz ${OUTPUT}

echo "result: $OUTPUT.tar.gz"

