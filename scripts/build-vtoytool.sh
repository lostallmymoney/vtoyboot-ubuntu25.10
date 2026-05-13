#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC_DIR="$ROOT/third_party/vtoytool-src"
OUT_DIR="$ROOT/tools"
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vtoytool-build.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT HUP INT TERM

copy_source() {
    cp -a "$SRC_DIR/." "$BUILD_DIR/"
}

build_target() {
    target=$1
    case "$target" in
        x86_64)
            cc=${CC_X86_64:-${CC:-gcc}}
            cflags="-static -O2 -D_FILE_OFFSET_BITS=64 -Wall -DBUILD_VTOY_TOOL -DVTOY_X86_64"
            outfile="$OUT_DIR/vtoytool_64"
            dump_link="$OUT_DIR/vtoydump64"
            ;;
        i386)
            cc=${CC_I386:-gcc}
            cflags="-static -O2 -D_FILE_OFFSET_BITS=64 -Wall -DBUILD_VTOY_TOOL -DVTOY_I386 -m32"
            outfile="$OUT_DIR/vtoytool_32"
            dump_link="$OUT_DIR/vtoydump32"
            ;;
        aa64|arm64|aarch64)
            cc=${CC_AA64:-aarch64-linux-gnu-gcc}
            cflags="-static -O2 -D_FILE_OFFSET_BITS=64 -Wall -DBUILD_VTOY_TOOL -DVTOY_AA64"
            outfile="$OUT_DIR/vtoytool_aa64"
            dump_link="$OUT_DIR/vtoydumpaa64"
            ;;
        m64e|mips64el)
            cc=${CC_M64E:-mips64el-linux-musl-gcc}
            cflags="-static -O2 -D_FILE_OFFSET_BITS=64 -Wall -DBUILD_VTOY_TOOL -DVTOY_MIPS64 -mips64r2 -mabi=64"
            outfile="$OUT_DIR/vtoytool_m64e"
            dump_link=""
            ;;
        *)
            echo "Unsupported target: $target" >&2
            exit 1
            ;;
    esac

    echo "Building $target with $cc"
    copy_source
    "$cc" $cflags "$BUILD_DIR"/*.c "$BUILD_DIR"/BabyISO/*.c -I"$BUILD_DIR"/BabyISO -o "$outfile"

    if [ -n "$dump_link" ]; then
        rm -f "$dump_link"
        ln -s "$(basename "$outfile")" "$dump_link"
    fi
}

if [ "$#" -eq 0 ]; then
    build_target x86_64
else
    for target in "$@"; do
        build_target "$target"
    done
fi
