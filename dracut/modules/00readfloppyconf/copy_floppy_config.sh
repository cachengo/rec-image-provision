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

USER_CONFIG_NAME="user_config.yaml"
CLOUD_CONFIGS="/tmp/cloud_configs"

source /usr/lib/installmedia-lib.sh

FLOPPYMOUNT="/tmp/floppy"

warn "copy_floppy_config: Checking if there are any floppy devices and cloud user yaml files in it."
if [ -d ${CLOUD_CONFIGS} ];then
  warn "copy_floppy_config: Seems Configs are fetched from CD. Returning from this module"
  return
fi

mkdir -p $FLOPPYMOUNT

# Define function to copy files to /tmp/cloud_configs
function copyfilesfromfloppy() {
    mount -o ro ${floppydev} $FLOPPYMOUNT
    if [ ! -e "$FLOPPYMOUNT/$USER_CONFIG_NAME" ];then
        warn "This filesystem does not contain user config... bailing out"
        umount $FLOPPYMOUNT
        return 1
    fi
    warn "copy files in ${floppydev} to ${CLOUD_CONFIGS}..."
    mkdir -p ${CLOUD_CONFIGS}
    cp -rf $FLOPPYMOUNT/* ${CLOUD_CONFIGS}
    umount $FLOPPYMOUNT
    return 0
}

read_devices
for device in "${hd_devices[@]}"; do
    if ( is_removable $device ); then
        #This device is a removable device. Check if it contains user_config
        floppydev="/dev/${device}"
        if ( copyfilesfromfloppy ); then
            warn "copy_floppy_config: Device found on ${floppydev}"
            break
        else
            floppydev=""
        fi
    fi
done

if [ -z ${floppydev} ]; then
    warn "copy_floppy_config: No floppy device found"
else
    warn "copy_floppy_config: Cloud configurations copied to ${CLOUD_CONFIGS}"
fi
