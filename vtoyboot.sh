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

vtoy_version=1.0.36

vtoyloop=0
for arg in "$@"; do
    if [ "$arg" = "__vtoyloop__" ]; then
        vtoyloop=1
        break
    fi
done

if [ "$vtoyloop" -eq 0 ] && readlink /proc/$$/exe | grep -q dash; then
    exec /bin/bash "$0" "$@" __vtoyloop__
fi

# Ubuntu 25.10 ("Questing") moved toward dracut as the default initrd stack.
# Some installs still expose update-initramfs compatibility, so distro-aware
# selection is safer than blindly preferring the first tool found.
vtoy_is_ubuntu_25_10() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        [ "$ID" = "ubuntu" ] && [ "$VERSION_ID" = "25.10" ]
        return
    fi
    false
}

# Select the integration backend that will actually rebuild the initrd with the
# Ventoy hook embedded. The per-backend vtoy.sh scripts do the real work.
vtoy_get_initrdtool_type() {
    . ./distros/initramfstool/check.sh
    . ./distros/mkinitcpio/check.sh
    . ./distros/dracut/check.sh

    if vtoy_is_ubuntu_25_10 && vtoy_check_dracut; then
        echo 'dracut'; return
    elif vtoy_check_initramfs_tool; then
        echo 'initramfstool'; return
    elif vtoy_check_mkinitcpio; then
        echo 'mkinitcpio'; return
    elif vtoy_check_dracut; then
        echo 'dracut'; return
    else
        echo 'unknown'; return
    fi
}

echo ''
echo '**********************************************'
echo "      vtoyboot $vtoy_version"
echo "      longpanda admin@ventoy.net"
echo "      https://www.ventoy.net"
echo '**********************************************'
echo ''

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or use sudo"
    echo ""
    exit 1
fi

if ! [ -d ./distros ]; then
    echo "Please run the script in the right directory"
    echo ""
    exit 1
fi

if [ -e /dev/mapper/ventoy ]; then
    :
else    
    for disk in /dev/sdb /dev/vdb /dev/hdb; do
        if [ -e "$disk" ]; then
            echo "More than one disks found. Currently only one disk is supported."
            echo ""
            exit 1
        fi
    done
fi

initrdtool=$(vtoy_get_initrdtool_type)

if ! [ -f "./distros/$initrdtool/vtoy.sh" ]; then
    echo 'Current OS is not supported!'
    exit 1
fi

vtoyboot_need_proc_ibt() {
    vtTool=$1
    vtKv=$(uname -r)
    vtMajor=$(echo $vtKv | awk -F. '{print $1}')
    vtMinor=$(echo $vtKv | awk -F. '{print $2}')
    
    #ibt was supported since linux kernel 5.18
    if [ $vtMajor -lt 5 ]; then
        false; return
    elif [ $vtMajor -eq 5 ]; then
        if [ $vtMinor -lt 18 ]; then
            false; return
        fi
    fi
    
    if grep -q ' ibt=off' /proc/cmdline; then
        false; return
    fi

    #hardware CPU doesn't support IBT
    if $vtTool vtoykmod -I; then
        :
    else
        false; return
    fi
    
    #dot.CONFIG not enabled
    if grep -q ' ibt_restore$' /proc/kallsyms; then
        :
    else
        false; return
    fi
    
    true
}

#prepare vtoydump
case "$(uname -m)" in
    x86_64|amd64)
    vtdumpcmd=./tools/vtoydump64
    partxcmd=./tools/vtoypartx64
    vtcheckcmd=./tools/vtoycheck64
    vtoytool=./tools/vtoytool_64
    ;;
    aarch64|arm64)
    vtdumpcmd=./tools/vtoydumpaa64
    partxcmd=./tools/vtoypartxaa64
    vtcheckcmd=./tools/vtoycheckaa64
    vtoytool=./tools/vtoytool_aa64
    ;;
    *)
    vtdumpcmd=./tools/vtoydump32
    partxcmd=./tools/vtoypartx32
    vtcheckcmd=./tools/vtoycheck32
    vtoytool=./tools/vtoytool_32
    ;;
esac

chmod +x "$vtdumpcmd" "$partxcmd" "$vtcheckcmd"

for vsh in ./distros/"$initrdtool"/*.sh; do
    chmod +x "$vsh"
done

echo "Current system use $initrdtool as initramfs tool"
# Hand off to the backend-specific installer. This script is mainly responsible
# for environment checks, backend selection, and tool path setup.
if . ./distros/"$initrdtool"/vtoy.sh "$@"; then
    sync
    echo ""
    echo "vtoyboot process successfully finished."
    echo ""
else
    echo ""
    echo "vtoyboot process failed, please check."
    echo ""
    exit 1
fi
