#!/usr/bin/env python3
#
# Build the "temporary boot" (fastboot boot) variant of the recovery image.
#
# This tree is built with BOARD_USES_RECOVERY_AS_BOOT := true, i.e. the boot
# image *is* the recovery ramdisk and is also used for normal boots.  AOSP's
# first-stage init decides what to do based on the boot reason:
#
#   system/core/init/first_stage_init.cpp
#   bool ForceNormalBoot(const std::string& cmdline, const std::string& bootconfig) {
#       bool twrp_fastboot = cmdline.find("twrpfastboot=1") == std::string::npos;
#       bool normal_boot = bootconfig.find("androidboot.force_normal_boot = \"1\"") != std::string::npos ||
#                          cmdline.find("androidboot.force_normal_boot=1") != std::string::npos;
#       return twrp_fastboot && normal_boot;
#   }
#
# * normal boot (the bootloader passes androidboot.force_normal_boot=1, and that is
#   also what `fastboot boot` does) -> init mounts the installed /system and execs
#   its init, i.e. the ROM boots, *not* recovery;
# * recovery boot (no force_normal_boot) -> TWRP runs.
#
# TWRP patched init so that the boot header cmdline flag twrpfastboot=1 disables
# that handoff.  This script copies the freshly built boot image and sets that flag
# in the header cmdline, producing the image to use with `fastboot boot`.
#
# Do NOT flash the produced image into the boot partition: with the flag baked in
# the device would always start into recovery.
#
# Usage:
#   python3 make_fbboot_image.py [in.img] [out.img]
# Defaults: out/target/product/pipa/boot.img -> <same dir>/boot-fbboot.img
#
import hashlib
import os
import struct
import sys

MAGIC = b"ANDROID!"
FLAG = b"twrpfastboot=1"
CMDLINE_OFFSET = 0x2C   # boot header v3/v4: magic(8) kernel_size(4) ramdisk_size(4)
                        # os_version(4) header_size(4) reserved[4](16) header_version(4)
CMDLINE_SIZE = 512


def patch(src, dst):
    with open(src, "rb") as f:
        data = bytearray(f.read())

    if data[:8] != MAGIC:
        sys.exit("not an Android boot image: %s" % src)

    header_version = struct.unpack_from("<I", data, 0x28)[0]
    if header_version < 3:
        sys.exit("only boot header v3/v4 is supported (found v%d)" % header_version)

    cur = bytes(data[CMDLINE_OFFSET:CMDLINE_OFFSET + CMDLINE_SIZE]).split(b"\0")[0]
    if FLAG in cur.split(b" "):
        new_cmdline = cur
        print("cmdline already contains twrpfastboot=1")
    else:
        new_cmdline = FLAG + (b" " + cur if cur else b"")

    if len(new_cmdline) > CMDLINE_SIZE - 1:
        sys.exit("cmdline would not fit into the boot header")

    data[CMDLINE_OFFSET:CMDLINE_OFFSET + CMDLINE_SIZE] = (
        new_cmdline + b"\0" * (CMDLINE_SIZE - len(new_cmdline)))

    with open(dst, "wb") as f:
        f.write(data)

    print("in : %s" % src)
    print("out: %s (%d bytes)" % (dst, len(data)))
    print("cmdline: %s" % new_cmdline.decode("ascii", "replace"))
    print("sha256: %s" % hashlib.sha256(data).hexdigest())
    print()
    print("Use it with:  fastboot boot %s" % dst)
    print("Never flash this image, or the device will always boot into recovery.")


def main():
    args = sys.argv[1:]
    src = args[0] if args else os.path.join("out", "target", "product", "pipa", "boot.img")
    dst = args[1] if len(args) > 1 else os.path.join(os.path.dirname(src), "boot-fbboot.img")
    patch(src, dst)


if __name__ == "__main__":
    main()
