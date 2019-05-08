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

installkernel()
{
    instmods = 8021q virtio_net be2net mlx4_en mlx4_core mlx5_core mlx4_bi ixgbe mdio dca ptp pps_core tg3
}

depends() {
    echo nss-softokn
    return 0
}

install() {
    dracut_install wget curl ping /lib64/libnss_dns.so.2 /etc/nsswitch.conf
    inst_hook pre-udev 48 "$moddir/load_net_modules.sh"
    inst_hook pre-pivot 52 "$moddir/net_config_get_iso.sh"

    local _dir _crt _found _lib
    inst_multiple curl
    # also install libs for curl https
    inst_libdir_file "libnsspem.so*"
    inst_libdir_file "libnsssysinit.so*"
    inst_libdir_file "libsqlite3.so*"

    for _dir in $libdirs; do
        [[ -d $_dir ]] || continue
        for _lib in $_dir/libcurl.so.*; do
            [[ -e $_lib ]] || continue
            _crt=$(grep -F --binary-files=text -z .crt $_lib)
            [[ $_crt ]] || continue
            [[ $_crt == /*/* ]] || continue
            if ! inst_simple "$_crt"; then
                dwarn "Couldn't install '$_crt' SSL CA cert bundle; HTTPS might not work."
                continue
            fi
            _found=1
        done
    done
    [[ $_found ]] || dwarn "Couldn't find SSL CA cert bundle; HTTPS won't work."
}

