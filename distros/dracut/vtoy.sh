#!/bin/sh
#************************************************************************************
# Copyright (c) 2020, longpanda <admin@ventoy.net>
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>.
# 
#************************************************************************************

. ./tools/efi_legacy_grub.sh
. ./common/vtoy-common.sh

# Dracut module location varies by distro packaging. Ubuntu 25.10 uses the
# standard dracut layout, so pick the writable module tree dynamically.
if [ -e /lib/dracut/dracut-install ]; then
    vtmodpath=/lib/dracut/modules.d/99ventoy
else
    vtmodpath=/usr/lib/dracut/modules.d/99ventoy
fi

if [ -d /etc/dracut.conf.d ]; then
    dracutConfPath=/etc/dracut.conf.d
else
    dracutConfPath=/usr/lib/dracut/dracut.conf.d
fi


vtoy_clean_tools /bin
rm -f $dracutConfPath/ventoy.conf
rm -rf $vtmodpath
mkdir -p $vtmodpath

# Install the Ventoy dracut module plus the helper binaries that module calls
# during early boot to recreate the virtual disk mapping.
install_vtoy_tools /bin
install_vtoy_helper
cp -a ./distros/$initrdtool/module-setup.sh $vtmodpath/
cp -a ./distros/$initrdtool/ventoy-settled.sh $vtmodpath/

#early centos release doesn't have require_binaries
if [ -e $vtmodpath/../../dracut-functions ]; then
    if grep -q require_binaries $vtmodpath/../../dracut-functions; then
        :
    else
        sed "/require_binaries/d" -i $vtmodpath/module-setup.sh
    fi
fi


for md in $(cat ./tools/vtoydrivers); do
    if [ -n "$md" ]; then
        if modinfo -n $md 2>/dev/null | grep -q '\.ko'; then
            extdrivers="$extdrivers $md"
        fi
    fi
done


# Force the Ventoy dracut module into every rebuilt initrd and pre-load the
# storage-related drivers that Ventoy relies on.
cat >$dracutConfPath/ventoy.conf <<EOF
add_dracutmodules+=" ventoy "
force_drivers+=" $extdrivers "
EOF


echo "updating the initramfs, please wait ..."
dracut -f --no-hostonly

kv=$(uname -r)
for k in $(ls /lib/modules); do
    if [ "$k" != "$kv" ]; then
        echo "updating initramfs for $k please wait ..."
        dracut -f --no-hostonly --kver $k
    fi
done


run_vtoy_grub


if [ -e /sys/firmware/efi ]; then
    if [ -e /dev/mapper/ventoy ]; then
        echo "This is ventoy enviroment"
    else
        update_grub_config
        install_legacy_bios_grub
    fi
    
    if [ "$1" = "-s" ]; then
        recover_shim_efi
    else
        replace_shim_efi
    fi
    
    if [ -d /boot/EFI/EFI/mageia ]; then
        if ! [ -d /boot/EFI/EFI/boot ]; then
            mkdir -p /boot/EFI/EFI/boot
            if [ -f /boot/EFI/EFI/mageia/grubx64.efi ]; then
                cp -a /boot/EFI/EFI/mageia/grubx64.efi /boot/EFI/EFI/boot/bootx64.efi
            fi
        fi
    fi
    
fi

vtoy_post_efi "$@"
install_vtoy_udev_hide_rule
