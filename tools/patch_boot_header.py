#!/usr/bin/env python3
#
# Set the boot header os_version / os_patch_level of an Android boot image.
#
# Why this exists: the keymaster TA compares the values the HAL reports (which come
# from the boot image header) with the ones stored inside the /metadata key blob.
# An image whose header carries the ROM's values (17 / 2026-09) makes the TA answer
# KEY_REQUIRES_UPGRADE and then fail upgradeKey() with INVALID_ARGUMENT, so TWRP
# cannot decrypt /data. The values this tree's build produces
# (os_version=16.0.0, os_patch_level=2099-12) work. This is mainly useful for images
# produced by TWRP's "Install Recovery Ramdisk", which inherits the header from the
# boot image it repacks.
#
# Usage:
#   patch_boot_header.py <img> [os_version_hex] [os_patch_hex]
# Defaults to 0x2000063c (Android 16.0.0 + 2099-12), the value our builds produce.
#
import hashlib
import sys

MAGIC = b"ANDROID!"
OS_VERSION_OFFSET = 0x10
DEFAULT_VALUE = 0x2000063C


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    value = int(sys.argv[2], 0) if len(sys.argv) > 2 else DEFAULT_VALUE

    with open(path, "r+b") as f:
        data = bytearray(f.read(0x40))
        if data[:8] != MAGIC:
            sys.exit("not an Android boot image: %s" % path)
        header_version = int.from_bytes(data[0x28:0x2C], "little")
        if header_version < 3:
            sys.exit("only boot header v3/v4 is supported (found v%d)" % header_version)
        old = int.from_bytes(data[OS_VERSION_OFFSET:OS_VERSION_OFFSET + 4], "little")
        f.seek(OS_VERSION_OFFSET)
        f.write(value.to_bytes(4, "little"))

    print("file       : %s" % path)
    print("os_version : 0x%08x -> 0x%08x" % (old, value))
    print("             (0x%08x = Android %d.%d.%d + %04d-%02d)"
          % (value, (value >> 25) & 0x7F, (value >> 18) & 0x7F, (value >> 11) & 0x7F,
             2000 + ((value >> 4) & 0x7F), (value & 0xF) + 1))
    with open(path, "rb") as f:
        print("sha256     : %s" % hashlib.sha256(f.read()).hexdigest())


if __name__ == "__main__":
    main()
