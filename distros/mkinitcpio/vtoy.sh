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

# Remove older Ventoy hook/install artifacts before rebuilding initramfs so the
# current run is deterministic.
vtoy_clean_env() {
    vtoy_clean_tools /sbin
    rm -f /usr/lib/initcpio/hooks/ventoy
    rm -f /usr/lib/initcpio/install/ventoy
}

vtoy_clean_env

# Install the helper binaries and mkinitcpio hook definitions into the guest OS,
# then rebuild every preset so Ventoy's mapper setup runs during early boot.
install_vtoy_tools /sbin
install_vtoy_helper
cp -a ./tools/vtoydrivers /sbin/vtoydrivers
cp -a ./distros/$initrdtool/ventoy-install.sh  /usr/lib/initcpio/install/ventoy
cp -a ./distros/$initrdtool/ventoy-hook.sh  /usr/lib/initcpio/hooks/ventoy

echo "updating the initramfs, please wait ..."

if ! grep -q '^HOOKS=.*ventoy' /etc/mkinitcpio.conf; then
    # Keep Ventoy adjacent to the storage-unlock hooks so the mapped disk exists
    # before the normal root discovery logic continues.
    if grep -q '^HOOKS=.*lvm' /etc/mkinitcpio.conf; then
        exthook='ventoy'
    else
        exthook='lvm2 ventoy'
    fi

    if grep -q '^HOOKS=.*encrypt' /etc/mkinitcpio.conf; then
        sed "s/\(^HOOKS=.*\)encrypt/\1 $exthook encrypt/" -i /etc/mkinitcpio.conf
    elif grep -q "^HOOKS=\"" /etc/mkinitcpio.conf; then    
        sed "s/^HOOKS=\"\(.*\)\"/HOOKS=\"\1 $exthook\"/" -i /etc/mkinitcpio.conf
    elif grep -q "^HOOKS=(" /etc/mkinitcpio.conf; then    
        sed "s/^HOOKS=(\(.*\))/HOOKS=(\1 $exthook)/" -i /etc/mkinitcpio.conf
    fi
fi

mkinitcpio -P

run_vtoy_grub

vtoy_post_efi "$@"
install_vtoy_udev_hide_rule
