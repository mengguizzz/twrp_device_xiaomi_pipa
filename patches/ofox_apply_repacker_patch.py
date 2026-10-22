#!/usr/bin/env python3
"""Insert Normalize_Repacked_Image() into TWRP's twrpRepacker.cpp."""
import sys
import os
import re
from pathlib import Path

HELPER_FILE = Path(__file__).resolve().parent / "repacker_normalize.cpp.txt"

INCLUDE_BLOCKS = (
    (
        "#include <format>\n#include <string>\n#include <sys/mount.h>\n#include <sys/wait.h>\n",
        "#include <fcntl.h>\n"
        "#include <algorithm>\n"
        "#include <cstdint>\n"
        "#include <cstdlib>\n"
        "#include <cstring>\n"
        "#include <format>\n"
        "#include <string>\n"
        "#include <sys/mount.h>\n"
        "#include <sys/wait.h>\n"
        "#include <unistd.h>\n\n"
        "#include <android-base/properties.h>\n"
        "#include <android-base/unique_fd.h>\n",
    ),
    (
        '#include <string>\n\n#include "data.hpp"',
        "#include <fcntl.h>\n"
        "#include <algorithm>\n"
        "#include <cstdint>\n"
        "#include <cstdlib>\n"
        "#include <cstring>\n"
        "#include <string>\n"
        "#include <unistd.h>\n\n"
        "#include <android-base/properties.h>\n"
        "#include <android-base/unique_fd.h>\n\n"
        '#include "data.hpp"',
    ),
)

ANCHORS = (
    "bool twrpRepacker::PrepareEmptyFolder",
    "bool twrpRepacker::Prepare_Empty_Folder",
)

CALL_RE = re.compile(
    r'(?P<indent>\t*)std::string file = "new-boot.img";\n'
    r'(?P=indent)DataManager::SetValue\("tw_flash_partition", dest_partition \+ ";"\);'
)


def main():
    root = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else os.environ.get("TWRP_BUILD_DIR", os.getcwd())
    ).resolve()
    src_path = root / "bootable/recovery/twrpRepacker.cpp"
    src = src_path.read_text(encoding="utf-8")
    if "Normalize_Repacked_Image" in src:
        print("already patched")
        return
    helper = HELPER_FILE.read_text(encoding="utf-8")
    include_block = next(
        ((old, new) for old, new in INCLUDE_BLOCKS if old in src), None
    )
    if include_block is None:
        sys.exit("include block not found")
    anchor = next((candidate for candidate in ANCHORS if candidate in src), None)
    if anchor is None:
        sys.exit("anchor not found")
    if CALL_RE.search(src) is None:
        sys.exit("call site not found")
    src = src.replace(include_block[0], include_block[1], 1)
    src = src.replace(anchor, helper + anchor, 1)
    src = CALL_RE.sub(
        lambda match: (
            f'{match.group("indent")}std::string file = "new-boot.img";\n'
            f'{match.group("indent")}Normalize_Repacked_Image(path + file);\n'
            f'{match.group("indent")}DataManager::SetValue("tw_flash_partition", '
            'dest_partition + ";");'
        ),
        src,
    )
    src_path.write_text(src, encoding="utf-8")
    print("patched %s, call sites: %d" % (src_path, src.count("Normalize_Repacked_Image(path + file)")))


if __name__ == "__main__":
    main()
