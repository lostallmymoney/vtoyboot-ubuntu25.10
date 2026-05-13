# vtoyboot


PLEASE USE THE OPTION -s TO ENABLE SECURE BOOT !!!!

sudo sh vtoyboot.sh -s

`vtoyboot` modifies a Linux guest installed inside a `vhd`/`vdi`/`raw` image so
that the image can later boot through Ventoy on real hardware.

This directory is a normalized local project assembled from the original
`vtoyboot` package dump, the recovered source-side fragments, and source code
copied from the local `Ventoy-master` tree where available.

## Layout

- `vtoyboot.sh`
  Installer entry point. Detects the initramfs backend and installs the
  Ventoy early-boot hook.
- `distros/`
  Backend-specific logic for `initramfs-tools`, `dracut`, and `mkinitcpio`.
- `tools/`
  Runtime helpers used by the installer and by the generated initramfs.
- `third_party/vtoytool-src/`
  Vendored `VtoyTool` source copied from the local Ventoy tree.
- `scripts/build-vtoytool.sh`
  Rebuilds `tools/vtoytool_*` from vendored source when toolchains are present.
- `docs/helper-binaries.md`
  Source mapping for the helper binaries and current audit status.

## Local changes

- Added Ubuntu 25.10 backend preference so Questing uses `dracut` when present.
- Added comments across the runtime hooks and backend installers.
- Added `/dev/disk/by-uuid` and `/dev/disk/by-partuuid` link creation for the
  synthesized `ventoyN` mapper partitions during early boot.
- Replaced standalone `vtoydump*` Linux helpers with symlinks to `vtoytool_*`.
  `vtoytool` already exposes `vtoydump` as a multi-call entry point.
- Rebuilt `tools/vtoytool_64` locally from vendored source.

## Build

Rebuild the host `x86_64` helper:

```sh
./scripts/build-vtoytool.sh
```

Build a different target when the matching cross compiler is installed:

```sh
./scripts/build-vtoytool.sh i386
./scripts/build-vtoytool.sh aa64
./scripts/build-vtoytool.sh m64e
```

## Current source status

- `vtoytool_*`: source-backed in this tree via `third_party/vtoytool-src/`
- `vtoydump*`: phased out on Linux in favor of `vtoytool_*` symlinks
- `vtoypartx*`: still shipped as binaries; upstream source is `util-linux` `partx`
- `vtoycheck*`: still shipped as binaries; source was not recovered from this dump
- `vtoydmpatch*`: missing from this dump entirely; the remount path cannot be fully
  reproduced until that carrier binary or its source is recovered
