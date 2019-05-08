#!/bin/bash

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

export SYS_BLOCK="/sys/class/block"
export CONSOLE_DEV="/dev/tty0"
export BOOTCD_LOCATION="/run/boot.iso"
export CLOUD_CONFIGS="/tmp/cloud_configs"
if (! declare -f warn );then
    echo "warn function not defined assume running outside of dracut" > $CONSOLE_DEV
    alias warn=echo
fi

function is_using_boot_cd(){
    if [ -a $BOOTCD_LOCATION ];then
        return 0
    fi
    return 1
}

function logmsg(){
    message="$@"
    echo $message > $CONSOLE_DEV
    warn $message
}

function run_crit(){
    OUTPUT=$(echo $@ | /bin/bash)
    if [ $? -ne 0 ]; then
        logmsg "Failed to execute $@::$OUTPUT"
        exit 1
    fi
    echo $OUTPUT
}

function read_devices(){
    # Get list of block devices on the system
    device_list=$(ls $SYS_BLOCK)
    read -r -a hd_devices <<< $device_list
    export hd_devices
}

function check_params()
{
    if [ $1 -ne $(($#-1)) ];then
        echo "Not enough params for ${FUNCNAME[ 1 ]}" > $CONSOLE_DEV
        exit 1
    fi
}

function try_mount(){
    check_params 3 "$@"
    dev=$1
    device_mount=$2
    umount_on_found=$3
    if [ -e $dev ] && [ -b $dev ];then

        mount -o ro -t iso9660 $dev $device_mount
        if [ $? -ne 0 ];then
            return 1
        else
            if [ -e "$device_mount/guest-image.img" ];then
                if ( $umount_on_found ); then
                    umount $device_mount
                fi
                return 0
            else
                umount $device_mount
                return 1
            fi
        fi
    else
        return 1
    fi
}

function is_loop(){
    check_params 1 "$@"
    device=$1
    if [ -e $SYS_BLOCK/$device/loop ]; then
        return 0
    fi
    return 1
}

function is_partition(){
    check_params 1 "$@"
    device=$1
    if [ -e $SYS_BLOCK/$device/partition ];then
        return 0
    fi
    return 1
}

function is_removable(){
    check_params 1 "$@"
    device=$1
    sysdev=$SYS_BLOCK/$device
    if ( is_partition $device );then
        removable=$(readlink -f $sysdev/..)/removable
    else
        removable=$sysdev/removable
    fi
    if [ -e $removable ] && [ $(cat $removable) -eq 1 ];then
        return 0
    else
        return 1
    fi

}

function get_config_from_device_end(){
    check_params 1 "$@"
    local BOOTDEVICE=$1

    if [ -b $BOOTDEVICE ]; then
        SKIP=$(($(blockdev --getsize64 $BOOTDEVICE)/2048-32))
        dd if=$BOOTDEVICE of=/tmp/cloudconf.tgz bs=2k skip=$SKIP
        if gzip -t /tmp/cloudconf.tgz 2>/dev/null ; then
            logmsg "Copying cloud configurations to $CLOUD_CONFIGS"
            mkdir -p $CLOUD_CONFIGS
            tar xzf /tmp/cloudconf.tgz -C $CLOUD_CONFIGS
            return $?
        else
            return 1
        fi
    else
        return 1
    fi

}

function find_iso(){
    check_params 2 "$@"
    device_mount=$1
    umount_on_found=$2
    if [ ! -d $device_mount  ];then
       mkdir -p $device_mount
    fi
    read_devices
    for device in ${hd_devices[@]}; do
        if ( is_removable $device );then
            if ( try_mount /dev/$device $device_mount $umount_on_found );then
                logmsg "installmedia: found image from device $device."
                export BOOTDEVICE=/dev/${device}
                return 0
            fi
        fi
    done
    return 1
}
