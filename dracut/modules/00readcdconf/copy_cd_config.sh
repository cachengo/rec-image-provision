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

CONSOLE_DEV="/dev/tty0"
DEVICE_MOUNT="/tmp/cdrom"
BOOTDEVICE=""
CDROMDEV="/dev/sr0"
mkdir -p $DEVICE_MOUNT

source /usr/lib/installmedia-lib.sh

while [ -z $BOOTDEVICE ]; do
    find_iso $DEVICE_MOUNT true
    if [ $? -ne 0 ]; then
        #For boot_cd
        if ( get_config_from_device_end $CDROMDEV ); then
            logmsg "Found config from $CDROMDEV assuming boot_cd install"
            break
        fi
        warn "Could not find install media... Retrying..."
        echo "Could not find install media... Retrying..." > $CONSOLE_DEV
        sleep 2
    else
        get_config_from_device_end $BOOTDEVICE
        break
    fi
done

warn "copy_cd_config: Found ISO device. Proceeding."

