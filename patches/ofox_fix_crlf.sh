#!/bin/bash
set -euo pipefail

DEV=${1:-${TWRP_BUILD_DIR:-$(pwd)}/device/xiaomi/pipa}
DEV=$(realpath "$DEV")

if [ ! -d "$DEV" ]; then
    echo "Device tree not found: $DEV" >&2
    exit 1
fi

echo "=== before: CRLF count in fstab ==="
grep -c $'\r' "$DEV/recovery/root/system/etc/recovery.fstab" || true

echo
echo "=== convert device tree text files to LF ==="
find "$DEV" -type f \( -name '*.fstab' -o -name '*.flags' -o -name '*.rc' \
    -o -name '*.prop' -o -name '*.sh' -o -name '*.xml' -o -name '*.bp' \
    -o -name '*.mk' -o -name '*.txt' -o -name '*.conf' \) -print0 \
    | xargs -0 -r sed -i 's/\r$//'

echo
echo "=== after: CRLF count in fstab ==="
grep -c $'\r' "$DEV/recovery/root/system/etc/recovery.fstab" || true
