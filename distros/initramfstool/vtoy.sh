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

# Remove older Ventoy hook/install artifacts before rebuilding initramfs so the
# current run is deterministic.
vtoy_clean_env() {
    vtoy_clean_tools /sbin
    rm -f /usr/share/initramfs-tools/hooks/vtoy-hook.sh  
    rm -f /etc/initramfs-tools/scripts/local-top/vtoy-local-top.sh
}

# Ensure a fallback EFI boot entry exists. Some guest installs only place grub
# under the distro directory, but the raw/vdi/vhd image also needs a generic
# /EFI/BOOT/BOOTX64.EFI path to boot reliably on real hardware.
vtoy_efi_fixup() {
    if [ -d /boot/efi/EFI ]; then
        for f in 'boot/bootx64.efi' 'boot/BOOTX64.efi' 'boot/BOOTX64.EFI' 'BOOT/bootx64.efi' 'BOOT/BOOTX64.efi' 'BOOT/BOOTX64.EFI'; do
            if [ -f /boot/efi/EFI/$f ]; then
                return
            fi
        done
    fi

    Dirs=$(ls /boot/efi/EFI)
    
    if ! [ -d /boot/efi/EFI/boot ]; then
        mkdir -p /boot/efi/EFI/boot
    fi
    
    for d in $Dirs; do
        for e in 'grubx64.efi' 'GRUBX64.EFI' 'bootx64.efi' 'BOOTX64.EFI'; do
            if [ -f "/boot/efi/EFI/$d/$e" ]; then
                cp -a "/boot/efi/EFI/$d/$e" /boot/efi/EFI/boot/bootx64.efi
                return
            fi
        done        
    done
}

vtoy_fix_elementary_partuuid() {
    if grep -q 'elementary OS' /etc/os-release; then
        if grep -q '^PARTUUID=.* /boot/efi ' /etc/fstab; then
            part=$(grep ' /boot/efi ' /proc/mounts | awk '{print $1}')
            uuid=$(blkid -s UUID -o value $part)
            sed -i "s#^PARTUUID=.* /boot/efi #UUID=$uuid /boot/efi #g" /etc/fstab
            echo "Fix elementary OS PARTUUID $part"
        fi
    fi
}

. ./tools/efi_legacy_grub.sh
. ./common/vtoy-common.sh

vtoy_clean_env

# Install the helper binaries and initramfs-tools hooks into the guest OS, then
# rebuild the initramfs so Ventoy's mapper setup runs during early boot.
install_vtoy_tools /sbin
install_vtoy_helper
cp -a ./tools/vtoydrivers /sbin/vtoydrivers
cp -a ./distros/$initrdtool/vtoy-hook.sh  /usr/share/initramfs-tools/hooks/
cp -a ./distros/$initrdtool/vtoy-local-top.sh  /etc/initramfs-tools/scripts/local-top/

echo "updating the initramfs, please wait ..."
update-initramfs -u


run_vtoy_grub



# Refresh EFI-facing boot files after the initramfs/grub work.
vtoy_efi_pre_hook() {
    vtoy_fix_elementary_partuuid
}

vtoy_efi_post_hook() {
    vtoy_efi_fixup
}

vtoy_post_efi "$@"
install_vtoy_udev_hide_rule

