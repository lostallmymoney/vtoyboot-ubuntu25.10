#!/bin/sh

# Return "hide" when the given block device is the source partition for
# /dev/mapper/ventoy, so udev can hide it from desktop automounters.
if [ $# -ne 1 ]; then
    exit 1
fi

dev=$1
if [ ! -b "$dev" ]; then
    exit 1
fi

if [ ! -e /dev/mapper/ventoy ]; then
    exit 0
fi

dev=$(readlink -f "$dev" 2>/dev/null || echo "$dev")
maj=$(stat -c '%t' "$dev" 2>/dev/null)
min=$(stat -c '%T' "$dev" 2>/dev/null)
if [ -z "$maj" ] || [ -z "$min" ]; then
    exit 0
fi

maj=$(printf '%d' "0x$maj")
min=$(printf '%d' "0x$min")

if dmsetup deps /dev/mapper/ventoy 2>/dev/null | grep -q "($maj, $min)"; then
    printf 'hide'
fi
