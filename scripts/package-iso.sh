#!/bin/sh
set -eu

# Resolve the project root directory
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Extract version from vtoyboot.sh
VER=$(awk -F= '/^vtoy_version=/{gsub(/[[:space:]]/, "", $2); print $2}' "$ROOT/vtoyboot.sh")
PKG_NAME="vtoyboot-$VER"
OUT_ISO=${1:-"$ROOT/$PKG_NAME.iso"}

# Setup temporary staging area
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/vtoyboot-iso.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM

# Ensure xorriso is available
if ! command -v xorriso >/dev/null 2>&1; then
    echo "xorriso is required but not installed" >&2
    exit 1
fi

# Create the internal directory structure for the ISO
TARGET_DIR="$STAGE/$PKG_NAME"
mkdir -p "$TARGET_DIR"

# Copy files directly into the staging directory
# -r: recursive
# -L: follow/dereference symlinks (matches original tar -h)
cp -rL \
    "$ROOT/LICENSE" \
    "$ROOT/README.md" \
    "$ROOT/docs" \
    "$ROOT/distros" \
    "$ROOT/scripts" \
    "$ROOT/common" \
    "$ROOT/third_party" \
    "$ROOT/tools" \
    "$ROOT/toolsbuild.txt" \
    "$ROOT/vtoyboot.sh" \
    "$TARGET_DIR/"

# Generate the ISO
# The root of the ISO will contain the $PKG_NAME directory
xorriso -as mkisofs \
    -allow-lowercase \
    -R \
    -V "VTOYBOOT" \
    -P "VENTOY" \
    -p "https://www.ventoy.net" \
    -o "$OUT_ISO" \
    "$STAGE"

echo "Created $OUT_ISO"
