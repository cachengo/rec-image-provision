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

# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    # do not add this module by default
    return 255
}

depends ()
{
    echo readcdconf readfloppyconf netconfig
    return 0
}

installkernel()
{
    instmods = sr_mod mpt3sas raid_class scsi_transport_sas weak-updates/be2iscsi/be2iscsi ipmi_msghandler ipmi_devintf ipmi_si
}

install_python_module() {

    local src dst module
    if (($# != 3 )); then
         derror "install_python_module takes 3 arguments"
    fi
    src=$1/$3
    dst=$2/$3
    module=$3
    for file in $(find $src -type f -printf "%P\n"); do
        inst_simple $src/$file $dst/$file
    done
}

install() {
    dracut_install df du partprobe parted gunzip ip gzip fdisk find lsmod loadkeys iscsid iscsiadm sync qemu-img sgdisk python ipmitool
    inst_hook pre-udev 48 "$moddir/load_modules.sh"
    inst_hook pre-pivot 53 "$moddir/installmedia.sh"
    inst_simple "$moddir/installmedia-lib.sh" /usr/lib/installmedia-lib.sh
    cat "$moddir/python_files" | while read dep; do
        case "$dep" in
            *.so) inst_library $dep ;;
            *.py) inst_simple $dep ;;
            *) inst $dep ;;
        esac
    done

    src_dir="/usr/lib/python2.7/site-packages"
    dst_dir="/usr/lib/python2.7/site-packages"
    inst_simple $src_dir/__init__.py $dst_dir/__init__.py
    install_python_module $src_dir $dst_dir "hw_detector"
}

