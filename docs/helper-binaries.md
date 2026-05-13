# Helper binaries

This tree mixes source-backed helpers, partially-audited helpers, and one
missing helper family.

## Source-backed

`vtoytool_*`

- Source location in this tree: `third_party/vtoytool-src/`
- Local origin: copied from `Ventoy-master/VtoyTool/`
- Build path: `./scripts/build-vtoytool.sh`

`vtoydump*`

- Linux `vtoydump*` has been phased out in this tree by symlinking it to
  `vtoytool_*`
- Reason: `vtoytool` already exposes the `vtoydump` entry point as a multi-call
  subcommand, so a separate binary is unnecessary on Linux

## Upstream source identified, not yet vendored

`vtoypartx*`

- Upstream source family: `util-linux` `partx`
- Existing local note: `toolsbuild.txt` at the project root
- Why still shipped as binaries here:
  static cross-builds for all shipped architectures are not wired into this
  normalized project yet

## Binary kept for now

`vtoycheck*`

- Purpose inferred from runtime use and embedded strings:
  validates that the target disk is GPT and suitable for the legacy GRUB embed
  path used by `tools/efi_legacy_grub.sh`
- Embedded strings include:
  `usage: vtoycheck /dev/sdb`
  `EFI PART`
  `NOT gpt partition`
  `biosgrub partition exist`
- Status:
  source not recovered from the local dump, and not yet reimplemented in this
  normalized tree

## Missing from the dump

`vtoydmpatch*`

- the embedded early-boot remount logic expects `/bin/vtoydmpatch` or
  `/sbin/vtoydmpatch` in order to extract `dm_patch.ko`
- No `vtoydmpatch*` file exists anywhere in the current workspace
- Impact:
  the `VTOY_LINUX_REMOUNT` / dm-patch path cannot be fully reproduced from this
  dump alone
