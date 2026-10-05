#!/usr/bin/env python3
"""Insert Normalize_Repacked_Image() into TWRP's twrpRepacker.cpp."""
import sys

SRC = "/root/twrp16/bootable/recovery/twrpRepacker.cpp"
HELPER_FILE = "/tmp/repacker_normalize.cpp.txt"

OLD_INCLUDES = "#include <format>\n#include <string>\n#include <sys/mount.h>\n#include <sys/wait.h>\n"
NEW_INCLUDES = ("#include <fcntl.h>\n#include <format>\n#include <string>\n#include <sys/mount.h>\n"
                "#include <sys/wait.h>\n#include <unistd.h>\n\n"
                "#include <android-base/properties.h>\n")

ANCHOR = "bool twrpRepacker::Prepare_Empty_Folder"

CALL_OLD = ('\tDataManager::SetProgress(.75);\n\tstd::string file = "new-boot.img";\n'
            '\tDataManager::SetValue("tw_flash_partition", dest_partition + ";");\n'
            "\tif (!PartitionManager.Flash_Image(path, file)) {")
CALL_NEW = ('\tDataManager::SetProgress(.75);\n\tstd::string file = "new-boot.img";\n'
            "\tNormalize_Repacked_Image(path + file);\n"
            '\tDataManager::SetValue("tw_flash_partition", dest_partition + ";");\n'
            "\tif (!PartitionManager.Flash_Image(path, file)) {")


def main():
    src_path = sys.argv[1] if len(sys.argv) > 1 else SRC
    src = open(src_path, encoding="utf-8").read()
    if "Normalize_Repacked_Image" in src:
        print("already patched")
        return
    helper = open(HELPER_FILE, encoding="utf-8").read()
    if OLD_INCLUDES not in src:
        sys.exit("include block not found")
    if ANCHOR not in src:
        sys.exit("anchor not found")
    if src.count(CALL_OLD) < 1:
        sys.exit("call site not found")
    src = src.replace(OLD_INCLUDES, NEW_INCLUDES, 1)
    src = src.replace(ANCHOR, helper + ANCHOR, 1)
    src = src.replace(CALL_OLD, CALL_NEW)
    open(src_path, "w", encoding="utf-8").write(src)
    print("patched %s, call sites: %d" % (src_path, src.count("Normalize_Repacked_Image(path + file)")))


if __name__ == "__main__":
    main()
