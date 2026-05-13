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

###########################
###########################
#AUTO_INSERT_COMMON_FUNC

# Shared early-boot helpers start here. This script runs inside the generated
# initramfs before the real root filesystem is mounted.
ventoy_check_efivars() {
    if [ -e /sys/firmware/efi ]; then
        if grep -q efivar /proc/mounts; then
            :
        else
            if [ -e /sys/firmware/efi/efivars ]; then
                mount -t efivarfs efivarfs /sys/firmware/efi/efivars  >/dev/null 2>&1
            fi
        fi
    fi
}

ventoy_log() {
    echo "$@" >> /tmp/vtoy.log
}


ventoy_check_insmod() {
    if [ -f /bin/kmod ]; then
        [ -f /bin/insmod ] || ln -s /bin/kmod /bin/insmod
        [ -f /bin/lsmod ]  || ln -s /bin/kmod /bin/lsmod
    fi
}

ventoy_create_disk_id_links() {
    vtDev=$1
    vtName=$2
    vtRelPath="../../mapper/$vtName"

    vtUuid=$(blkid -s UUID -o value "$vtDev" 2>/dev/null)
    if [ -n "$vtUuid" ]; then
        [ -d /dev/disk/by-uuid ] || mkdir -p /dev/disk/by-uuid
        ln -sf "$vtRelPath" "/dev/disk/by-uuid/$vtUuid"
    fi

    vtPartUuid=$(blkid -s PARTUUID -o value "$vtDev" 2>/dev/null)
    if [ -n "$vtPartUuid" ]; then
        [ -d /dev/disk/by-partuuid ] || mkdir -p /dev/disk/by-partuuid
        ln -sf "$vtRelPath" "/dev/disk/by-partuuid/$vtPartUuid"
    fi
}

ventoy_dm_create_ventoy() {    
    dmsetup create ventoy /ventoy_table
    
    RAWDISKNAME=$(head -n1 /ventoy_table | awk '{print $4}')
    RAWDISKSHORT=${RAWDISKNAME#/dev/}
    RAWDISKSECS=$(cat /sys/class/block/$RAWDISKSHORT/size)
    
    echo "0 $RAWDISKSECS linear $RAWDISKNAME 0" > /ventoy_raw_table      
    dmsetup create $RAWDISKSHORT  /ventoy_raw_table    
    
    vret=$?    
    return $vret
}


vtoy_wait_for_device() {
    while ! vtoydump > /dev/null 2>&1; do
        sleep 0.5
    done
}

# Recreate the Ventoy-backed device-mapper nodes inside the initramfs so the
# guest OS can mount its root filesystem from the VHD/VDI/RAW container.
vtoy_device_mapper_proc() {
    #flush multipath before dmsetup
    multipath -F > /dev/null 2>&1

    vtoydump -L > /ventoy_table
    if ventoy_dm_create_ventoy; then
        :
    else
        sleep 3
        multipath -F > /dev/null 2>&1
        ventoy_dm_create_ventoy
    fi


    DEVDM=/dev/mapper/ventoy

    loop=0
    while ! [ -e $DEVDM ]; do
        sleep 0.5
        let loop+=1
        if [ $loop -gt 10 ]; then
            echo "Waiting for ventoy device ..." > /dev/console
        fi
        
        if [ $loop -gt 10 -a $loop -lt 15 ]; then
            multipath -F > /dev/null 2>&1
            ventoy_dm_create_ventoy
        fi
    done

    for ID in $(vtoypartx $DEVDM -oNR | grep -v NR); do
        PART_START=$(vtoypartx  $DEVDM -n$ID -oSTART,SECTORS | grep -v START | awk '{print $1}')
        PART_SECTOR=$(vtoypartx $DEVDM -n$ID -oSTART,SECTORS | grep -v START | awk '{print $2}')
        
        echo "0 $PART_SECTOR linear $DEVDM $PART_START" > /ventoy_part_table    
        dmsetup create ventoy$ID /ventoy_part_table
        ventoy_create_disk_id_links "/dev/mapper/ventoy$ID" "ventoy$ID"
    done

    rm -f /ventoy_table
    rm -f /ventoy_part_table
}

case $1 in
    prereqs)
       exit 0
       ;;
esac

#check for efivarfs
ventoy_check_efivars

if vtoydump -c > /dev/null 2>&1; then
    vtoy_wait_for_device
    vtoy_device_mapper_proc
fi
