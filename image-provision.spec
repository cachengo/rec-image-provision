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

Name:       image-provision
Version:    %{_version}
Release:    2%{?dist}
Summary:    Contains dracut modules used for provisioning master image from a boot CD.
License:    %{_platform_licence}
Source0:    %{name}-%{version}.tar.gz
Vendor:     %{_platform_vendor}
BuildArch:  noarch

BuildRequires: rsync
Requires: cloud-init, dracut, coreutils, parted, gzip, iproute, util-linux, findutils, kmod, kbd, iscsi-initiator-utils, qemu-img-ev, gdisk, tar, wget, curl, glibc, hw-detector

%description
This RPM contains dracut modules. They are used for provisioning master image from a boot CD.

%prep
%autosetup

%build

%install
mkdir -p %{buildroot}/usr/lib/dracut/modules.d/
mkdir -p %{buildroot}/etc/

rsync -av dracut/modules/00installmedia %{buildroot}/usr/lib/dracut/modules.d/
rsync -av dracut/modules/00readfloppyconf %{buildroot}/usr/lib/dracut/modules.d/
rsync -av dracut/modules/00readcdconf %{buildroot}/usr/lib/dracut/modules.d/
rsync -av dracut/modules/00netconfig %{buildroot}/usr/lib/dracut/modules.d/
rsync -av dracut/conf/dracut-provision.conf  %{buildroot}/etc/

%files
%defattr(0755,root,root)
/etc/dracut-provision.conf
/usr/lib/dracut/modules.d/00installmedia
/usr/lib/dracut/modules.d/00readfloppyconf
/usr/lib/dracut/modules.d/00readcdconf
/usr/lib/dracut/modules.d/00netconfig

%pre

%post
# Get the lateset kernel version, and prepare provisioning initrd based on it.
KVER=`ls --sort=v /boot/vmlinuz-* |grep -v rescue| tail -n1 |awk -F '/boot/vmlinuz-' '{print $2}'`
/usr/bin/dracut --nostrip --local --keep -f /boot/initrd-provisioning.img -M --nofscks --nomdadmconf --tmpdir /tmp --libdirs "/lib /lib64  /usr/lib /usr/lib64 /usr/local/lib /usr/local/lib64" --conf /etc/dracut-provision.conf --kver $KVER --confdir /usr/lib/dracut/dracut.conf.d/

#Disable network service. This is delaying boot due to dhcp retries. Normally ifcfg is good enough for single tries.
/bin/systemctl --no-reload disable network.service >/dev/null 2>&1 || :

# Diabling cloud-init services as we don't need any metadata quiery as done by cloud-init.
# We use cloud-init libraries to do growpart and resizefs. So  we need clould-init packages still.
#/bin/systemctl --no-reload disable cloud-config.service >/dev/null 2>&1 || :
#/bin/systemctl --no-reload disable cloud-final.service  >/dev/null 2>&1 || :
#/bin/systemctl --no-reload disable cloud-init.service   >/dev/null 2>&1 || :
#/bin/systemctl --no-reload disable cloud-init-local.service >/dev/null 2>&1 || :

# This is a temporary fix, for udev net rename rules. The guest image choosen as base image, removes the below file.
# When we build our own guest image, we can remove this fix from here.
if [ -h /etc/udev/rules.d/80-net-name-slot.rules ];then
  unlink /etc/udev/rules.d/80-net-name-slot.rules
fi

grep -q "net.ifnames=0" /etc/default/grub
if [[ $? == 0 ]];then
  sed -i 's/net.ifnames=0 //' /etc/default/grub
  grub2-mkconfig > /etc/grub2.cfg
fi


echo "%{_name} has been succesfully installed"

%preun

%postun

%clean
rm -rf %{buildroot}

# TIPS:
# File /usr/lib/rpm/macros contains useful variables which can be used for example to define target directory for man page.
