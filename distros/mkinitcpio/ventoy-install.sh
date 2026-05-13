#!/bin/bash
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

build() {
    # Bundle the userspace helpers that the runtime hook calls to discover the
    # Ventoy image layout and recreate the device-mapper topology in initramfs.
    add_binary "dd"
    add_binary "sort"
    add_binary "head"
    add_binary "find"
    add_binary "xzcat"
    add_binary "zcat"
    add_binary "basename"
    add_binary "blkid"
    add_binary "vtoydump"
    add_binary "vtoypartx"
    add_binary "vtoytool"

    # Carry the storage-related kernel modules that Ventoy commonly needs before
    # the normal root device can be resolved.
    for md in $(cat /sbin/vtoydrivers); do
        if [ -n "$md" ]; then
            if modinfo -n $md 2>/dev/null | grep -q '\.ko'; then
                add_module $md
            fi
        fi
    done

    # Register the runtime hook defined in hooks/ventoy.
    add_runscript
}

help() {
  cat <<HELPEOF
This hook enables ventoy in initramfs.
HELPEOF
}
