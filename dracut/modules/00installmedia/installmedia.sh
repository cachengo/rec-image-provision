#!/bin/sh

# Copyright 2019 Nokia

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DEVICE_MOUNT="/tmp/installmedia"
CLOUD_RPMS_DIR="/sysroot/var/cloud/basebuild_rpms"
USERCONFIG_DIR="/sysroot/etc/userconfig/"
IMAGE_DIR="/sysroot/opt/images"

source /usr/lib/installmedia-lib.sh

logmsg "Installing OS to HDD"

mkdir -p $DEVICE_MOUNT

if ( is_using_boot_cd );then
  warn "Must be boot_cd env. Mounting $BOOTCD_LOCATION"
  run_crit mount -o ro -t iso9660 $BOOTCD_LOCATION $DEVICE_MOUNT
else
  find_iso $DEVICE_MOUNT false
  if [ $? -ne 0 ];then
    logmsg "No ISO image to install. Cannot proceed!"
    exit 1
  fi
fi

if [ -e $CLOUD_CONFIGS/network_config ];then
  logmsg "Sourcing network_config"
  source $CLOUD_CONFIGS/network_config
fi

if [ -n "${ROOTFS_DISK}" ];then
    rootdev_by_path=${ROOTFS_DISK}
else
    # Find out the disk name where rootfs has to be installed
    rootdev_by_path=$(python /usr/lib/python2.7/site-packages/hw_detector/local_os_disk.py)
fi

rootdev=$(readlink -e $rootdev_by_path)

#Wait for the device to appear for 60 seconds and then give up
while [ -z "${rootdev}" ]; do
    sleep 3
    rootdev=$(readlink -e $rootdev_by_path)
    count=$(( ${count}+1 ))
    if [ ${count} == 20 ]; then
       break
    fi
done

if [ -z ${rootdev} ] || ! [ -b ${rootdev} ]; then
  logmsg "No matching HDD (${rootdev}) found to install OS image. Cannot proceed!"
  exit 1
fi
if ! [ -e $DEVICE_MOUNT/guest-image.img ]; then
  logmsg "No guest-image.img in CDROM. Cannot proceed!"
  exit 1
fi

logmsg "Matching device found for root disk. Installing image on ${rootdev}"

read_devices
for hd_dev in ${hd_devices[@]}; do
    if [ -b /dev/$hd_dev ] && (( is_removable $hd_dev ) || ( is_partition $hd_dev ) || ( is_loop $hd_dev )); then
        logmsg "Removable, loop or partition $hd_dev. Skipping..."
        continue
    elif ! [ -b /dev/$hd_dev ];then
        continue
    fi
    logmsg "Erasing existing GPT and MBR data structures from ${hd_dev}"
    sgdisk -Z /dev/$hd_dev
    dd if=/dev/zero of=/dev/$hd_dev bs=1M count=1
done

logmsg "Dumping $DEVICE_MOUNT/guest-image.img to $rootdev"

# limit the memory usage for qemu-img to 1 GiB
ulimit -v 1048576
qemu-img convert -p -t directsync -O raw $DEVICE_MOUNT/guest-image.img $rootdev > $CONSOLE_DEV
if [ $? -ne 0 ]; then
    logmsg "Failed to dump image to disk... Failing installation."
    exit 255
fi
sync

logmsg "${rootdev} dumped successfully!"
echo "Finishing installation... Please wait." > $CONSOLE_DEV

sgdisk -e ${rootdev}
sleep 3
partprobe ${rootdev}
# create a new partion for LVMs before rootfs expands till end
parted ${rootdev} --script -a optimal -- mkpart primary 50GiB -1
partprobe ${rootdev}

sleep 3
mount ${rootdev}3 /sysroot/
mount ${rootdev}1 /sysroot/boot/efi
if [ $? -ne 0 ];then
    logmsg "FAILED TO MOUNT SYSROOT. All hope is lost"
    exit 255
fi

kernel_cmdline="intel_iommu=on iommu=pt crashkernel=256M"
# Check if this has a iscsi target if so, add extra cmdline option for HDD boot.
iscsiadm -m fw >/dev/null 2>&1
if [[ $? == 0 ]]; then
  kernel_cmdline="${kernel_cmdline} rd.iscsi.firmware=1 rd.retry=30"
fi
if grep -q "^GRUB_CMDLINE_LINUX=" /sysroot/etc/default/grub; then
  sed -i "s/^\(GRUB_CMDLINE_LINUX=.*\)\"$/\1 $kernel_cmdline\"/g" /sysroot/etc/default/grub
else
  echo "GRUB_CMDLINE_LINUX=\"$kernel_cmdline\"" >> /sysroot/etc/default/grub
fi

run_crit mount -o bind /dev /sysroot/dev
run_crit mount -o bind /proc /sysroot/proc
run_crit mount -o bind /sys /sysroot/sys
run_crit chroot /sysroot /bin/bash -c \"/usr/sbin/grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg\"

logmsg "Extending partition and filesystem size"
run_crit chroot /sysroot /bin/bash -c \"growpart ${rootdev} 3\"
run_crit chroot /sysroot /bin/bash -c \"resize2fs ${rootdev}3\"

logmsg "Copying cloud guest image"
mkdir -p $IMAGE_DIR
run_crit cp -f $DEVICE_MOUNT/guest-image.img $IMAGE_DIR

if [ -d $CLOUD_CONFIGS ]; then
  logmsg "Copying user config"
  mkdir -p $USERCONFIG_DIR
  cp -rf $CLOUD_CONFIGS/* $USERCONFIG_DIR
fi

if [ -e $DEVICE_MOUNT/rpms ]; then
    logmsg "Copying build base RPMs"
    mkdir -p $CLOUD_RPMS_DIR
    echo -n "."
    for file in $DEVICE_MOUNT/rpms/*;do
        cp -a $file $CLOUD_RPMS_DIR
        echo -n "." > $CONSOLE_DEV
    done
    echo -n " done" > $CONSOLE_DEV
    echo > $CONSOLE_DEV
    echo > $CONSOLE_DEV
fi

logmsg "Disabling cloud-init services on this node"
run_crit chroot /sysroot /bin/systemctl --no-reload disable cloud-config.service
run_crit chroot /sysroot /bin/systemctl --no-reload disable cloud-final.service
run_crit chroot /sysroot /bin/systemctl --no-reload disable cloud-init.service
run_crit chroot /sysroot /bin/systemctl --no-reload disable cloud-init-local.service


logmsg "Copying installation logs"
mkdir -p /sysroot/var/log/provisioning-logs
cp -rf /run/log/ /sysroot/var/log/provisioning-logs/
cp -rf /run/initramfs/ /sysroot/var/log/provisioning-logs/


sync
umount /sysroot/dev
umount /sysroot/proc
umount /sysroot/sys
umount /sysroot
umount $DEVICE_MOUNT
sleep 2
logmsg "Everything done rebooting!"
reboot -f
