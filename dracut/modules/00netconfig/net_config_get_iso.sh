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


source /usr/lib/installmedia-lib.sh

if [ -e /tmp/cloud_configs/network_config ];then
    warn "net_config_get_iso: Creating local network configurations, to download boot.iso."
    source /tmp/cloud_configs/network_config

    if [ $VLAN ]; then
      warn "net_config_get_iso: Configuring VLAN network"
      ip link add link $DEV name ${DEV}.${VLAN} type vlan id $VLAN
      ip a a $IP dev ${DEV}.${VLAN}
      ip link set up dev ${DEV}.${VLAN}
      ip link set up dev ${DEV}
      ip r a default via ${DGW} dev ${DEV}.${VLAN}
      EXT_DEV="${DEV}.${VLAN}"
    else
      warn "net_config_get_iso: Configuring non-VLAN network"
      ip a a $IP dev ${DEV}
      ip link set up dev ${DEV}
      ip r a default via ${DGW} dev ${DEV}
      EXT_DEV="${DEV}"
    fi
    
    wait_count=0
    ip link show ${EXT_DEV} | grep "LOWER_UP" > /dev/null 2>&1
    while [ $? != 0 ]
    do
      sleep 2
      ((wait_count++))
      if [[ $wait_count == 10 ]]; then
        warn "net_config_get_iso: Link on ${EXT_DEV} did not come-up. Cannot proceed!"
        exit 1
      fi
      warn "net_config_get_iso: Waiting for link to come-up on ${EXT_DEV}..."
      ip link show ${EXT_DEV} | grep "LOWER_UP" > /dev/null 2>&1
    done
    
    warn "net_config_get_iso: Link on ${EXT_DEV} came-up. Proceeding."
    
    if [ ${NAMESERVER} ]; then
      echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
    fi
    
    # Check if DGW is pinging. If not exit. User may want to cross-check his network_config file and network and fix it.
    warn "net_config_get_iso: Checking if DGW ${DGW} is pinging."
    ping_wait_count=0
    gw_ping_status=1
    while [ ${gw_ping_status} != 0 ]
    do
        ((ping_wait_count++))
        if [[ ${ping_wait_count} == 120 ]]; then
            warn "net_config_get_iso: Provided default gateway ${DGW} is not pinging. Exiting installation."
            exit 1
        fi
        if [[ ${DGW} = *:* ]]; then
            ping -6 -c 1 -w 1 ${DGW} > /dev/null 2>&1
        else
            ping -c 1 -w 1 ${DGW} > /dev/null 2>&1
        fi
        gw_ping_status=$?
    done
    
    warn "Downloading Full ISO from URL: ${ISO_URL}"
    if ! wget --connect-timeout 5 --read-timeout 100 --no-check-certificate ${ISO_URL} --progress=dot:giga -O $BOOTCD_LOCATION; then
        warn "net_config_get_iso: Failed to download ISO from URL: ${ISO_URL}. Exiting installation."
        exit 1
    fi
fi
