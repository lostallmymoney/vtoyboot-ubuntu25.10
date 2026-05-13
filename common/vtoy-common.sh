#!/bin/sh

vtoy_clean_tools() {
    bindir=${1:-/sbin}
    rm -f "$bindir/vtoydump" "$bindir/vtoypartx" "$bindir/vtoytool" "$bindir/vtoydrivers"
}

install_vtoy_tools() {
    bindir=$1
    cp -a "$vtdumpcmd" "$bindir/vtoydump"
    cp -a "$partxcmd" "$bindir/vtoypartx"
    cp -a "$vtoytool" "$bindir/vtoytool"
}

install_vtoy_helper() {
    if [ ! -e /usr/local/bin/vtoy-hide-ventoy.sh ]; then
        cp -a ./common/vtoy-hide-ventoy.sh /usr/local/bin/vtoy-hide-ventoy.sh
        chmod +x /usr/local/bin/vtoy-hide-ventoy.sh
    fi
}

install_vtoy_udev_hide_rule() {
    if [ -e /usr/local/bin/vtoy-hide-ventoy.sh ]; then
        cat > /etc/udev/rules.d/99-hide-ventoy.rules << 'EOF'
SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", PROGRAM="/usr/local/bin/vtoy-hide-ventoy.sh /dev/%k", RESULT=="hide", ENV{UDISKS_IGNORE}="1"
EOF
        udevadm control --reload-rules
        udevadm trigger --subsystem-match=block
    fi
}

run_vtoy_grub_mkconfig() {
    PROBE_PATH=$(find_grub_probe_path)
    MKCONFIG_PATH=$(find_grub_mkconfig_path)
    EDITENV_PATH=$(find_grub_editenv_path)
    echo "PROBE_PATH=$PROBE_PATH EDITENV_PATH=$EDITENV_PATH MKCONFIG_PATH=$MKCONFIG_PATH"

    if [ -e "$PROBE_PATH" ] && [ -e "$MKCONFIG_PATH" ]; then
        wrapper_grub_probe $PROBE_PATH

        if [ -e "$EDITENV_PATH" ]; then
            wrapper_grub_editenv $EDITENV_PATH
        fi

        GRUB_CFG_PATH=$(find_grub_config_path)
        if [ -f "$GRUB_CFG_PATH" ]; then
            echo "$MKCONFIG_PATH -o $GRUB_CFG_PATH"
            $MKCONFIG_PATH -o "$GRUB_CFG_PATH"
        else
            echo "$MKCONFIG_PATH null"
            $MKCONFIG_PATH > /dev/null 2>&1
        fi
    fi
}

run_vtoy_grub() {
    disable_grub_os_probe
    echo "grub mkconfig ..."
    run_vtoy_grub_mkconfig
}

vtoy_efi_pre_hook() {
    :
}

vtoy_efi_post_hook() {
    :
}

vtoy_post_efi() {
    if [ -e /sys/firmware/efi ]; then
        if [ -e /dev/mapper/ventoy ]; then
            echo "This is ventoy enviroment"
        else
            vtoy_efi_pre_hook "$@"
            update_grub_config
            install_legacy_bios_grub
        fi

        if [ "$1" = "-s" ]; then
            recover_shim_efi
        else
            replace_shim_efi
        fi

        vtoy_efi_post_hook "$@"
    fi
}
