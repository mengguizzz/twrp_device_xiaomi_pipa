#!/usr/bin/env python3
"""Patch TWRP's /etc/twrp.flags parser.

/etc/twrp.flags uses the TWRP v1 layout

    <mount point>  <fstype>  <device>  [<device2>]  flags=<...>

but `parse_twrp_flags()` in bootable/recovery/partition.cpp took tokens[1]
(the *fstype*, e.g. "emmc") as Primary_Block_Device and treated the real device
as the alternate.  Override_Block_Devices_From_Flags() then clobbered the device
that was parsed from /etc/recovery.fstab with that bogus value, so for /boot and
/dtbo (whose nodes only exist as boot_b / dtbo_b - there is no unsuffixed
by-name/boot) Actual_Block_Device ended up empty and
"Install Recovery Ramdisk" aborted in Backup_Image_For_Repack() with

    Backing up Boot...
    Error opening: '' (No such file or directory)

This patch reads the device from tokens[2] instead.
"""
import sys

OLD = """            if (!tokens.empty()) {
                lf.File_System = tokens[0];
                if (tokens.size() > 1)
                    lf.Primary_Block_Device = tokens[1];
                for (const auto &tok: tokens | std::views::drop(2)) {
                    if (tok[0] == '/')
                        lf.Alternate_Block_Device = tok;
                    else if (tok.size() > 6 && tok.starts_with("flags=")) {
                        lf.Flags = tok;
                        break;
                    }
                }
            }
"""

NEW = """            if (!tokens.empty()) {
                // /etc/twrp.flags (TWRP v1 layout):
                //   <mount point> <fstype> <device> [<device2>] flags=<...>
                // The block device is tokens[2] - taking tokens[1] put the fstype
                // ("emmc"/"ext4") into Primary_Block_Device, and then
                // Override_Block_Devices_From_Flags() replaced the real device
                // parsed from /etc/recovery.fstab with it. For /boot and /dtbo
                // (nodes only exist as boot_b/dtbo_b) that left
                // Actual_Block_Device empty and made "Install Recovery Ramdisk"
                // fail with "Error opening: '' (No such file or directory)".
                lf.File_System = tokens.size() > 1 ? tokens[1] : std::string();
                if (tokens.size() > 2)
                    lf.Primary_Block_Device = tokens[2];
                for (const auto &tok: tokens | std::views::drop(3)) {
                    if (tok[0] == '/')
                        lf.Alternate_Block_Device = tok;
                    else if (tok.size() > 6 && tok.starts_with("flags=")) {
                        lf.Flags = tok;
                        break;
                    }
                }
            }
"""

path = sys.argv[1] if len(sys.argv) > 1 else \
    "/root/twrp16/bootable/recovery/partition.cpp"

src = open(path, encoding="utf-8").read()
if NEW in src:
    print("already patched")
    sys.exit(0)
if OLD not in src:
    sys.exit("pattern not found - check partition.cpp")
open(path, "w", encoding="utf-8").write(src.replace(OLD, NEW, 1))
print("patched %s" % path)
