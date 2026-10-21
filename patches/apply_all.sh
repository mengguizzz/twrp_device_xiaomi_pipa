#!/bin/bash
set -euo pipefail

ROOT=${1:-${TWRP_BUILD_DIR:-$(pwd)}}
ROOT=$(realpath "$ROOT")
PATCH_DIR=$(dirname "$(realpath "$0")")

if [ ! -d "$ROOT/.repo" ] || [ ! -d "$ROOT/bootable/recovery" ]; then
    echo "Not a TWRP source tree: $ROOT" >&2
    exit 1
fi

python3 "$PATCH_DIR/ofox_patcher.py" "$ROOT"
cp -f "$PATCH_DIR/magisk_prebuilt_Android.bp" \
    "$ROOT/external/magisk-prebuilt/Android.bp"
if [ -f "$ROOT/external/magisk-prebuilt/Android.mk" ]; then
    mv -f "$ROOT/external/magisk-prebuilt/Android.mk" \
        "$ROOT/external/magisk-prebuilt/Android.mk.disabled"
fi
python3 "$PATCH_DIR/ofox_patch3.py" "$ROOT"
python3 "$PATCH_DIR/ofox_patch_twrpflags.py" \
    "$ROOT/bootable/recovery/partition.cpp"
python3 "$PATCH_DIR/ofox_apply_repacker_patch.py" "$ROOT"
python3 "$PATCH_DIR/ofox_patch_volume_keys.py" "$ROOT"
