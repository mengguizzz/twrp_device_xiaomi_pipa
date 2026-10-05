#!/bin/bash
SUDO() { echo 314159 | sudo -S -p '' "$@"; }
T=/root/twrp16
DEV=$T/device/xiaomi/pipa

echo "=== before: CRLF count in fstab ==="
SUDO bash -c "grep -c \$'\r' $DEV/recovery/root/system/etc/recovery.fstab || true"

echo
echo "=== convert device tree text files to LF ==="
SUDO bash -c "cd $DEV && find . -type f \( -name '*.fstab' -o -name '*.flags' -o -name '*.rc' -o -name '*.prop' -o -name '*.sh' -o -name '*.xml' -o -name '*.bp' -o -name '*.mk' -o -name '*.txt' -o -name '*.conf' \) -print0 | xargs -0 -r sed -i 's/\r\$//'"
SUDO bash -c "grep -c \$'\r' $DEV/recovery/root/system/etc/recovery.fstab || true"
SUDO bash -c "head -c 60 $DEV/recovery/root/system/etc/recovery.fstab | xxd | head -4"

echo
echo "=== also the built ramdisk copy (will be regenerated) ==="
SUDO bash -c "cd $T/out/target/product/pipa/recovery/root && find . -name '*.fstab' -o -name 'twrp.flags' | head -5"

echo
echo "=== relaunch build ==="
SUDO rm -f /tmp/ofox-build.log /tmp/ofox-build.pid
SUDO bash -c "nohup /tmp/ofox_build_inner.sh > /tmp/ofox-build.log 2>&1 & echo \$! > /tmp/ofox-build.pid"
sleep 8
echo "pid: $(SUDO cat /tmp/ofox-build.pid)"
