#!/usr/bin/env python3
"""Map the hardware volume keys to TWRP graphical list scrolling."""

from pathlib import Path
import os
import sys

root = Path(
    sys.argv[1]
    if len(sys.argv) > 1
    else os.environ.get("TWRP_BUILD_DIR", os.getcwd())
).resolve()
path = root / "bootable/recovery/gui/hardwarekeyboard.cpp"
source = path.read_text(encoding="utf-8")

MARKER = "TWRP_VOLUME_KEY_SCROLL"
if MARKER in source:
    print("volume-key scrolling already patched")
    raise SystemExit(0)

KEYDOWN_OLD = """\tkey_code = TranslateKeyCode(key_code);
\tmPressedKeys.insert(key_code);
"""
KEYDOWN_NEW = f"""\tkey_code = TranslateKeyCode(key_code);
\tmPressedKeys.insert(key_code);
\t// {MARKER}: the graphical UI has no default volume-key handler.
\t// Treat volume up/down as wheel scroll steps for the active list.
\tif (key_code == KEY_VOLUMEUP || key_code == KEY_VOLUMEDOWN) {{
\t\tint scroll_x = 0;
\t\tint scroll_y = 0;
\t\tPageManager::GetMouseCursor()->GetPos(scroll_x, scroll_y);
\t\tPageManager::NotifyScroll(scroll_x, scroll_y,
\t\t\t\tkey_code == KEY_VOLUMEUP ? 1 : -1);
\t\tmLastKeyChar = 0;
\t\tmLastKey = 0;
\t\treturn 0;
\t}}
"""

KEYUP_OLD = """\tkey_code = TranslateKeyCode(key_code);
\tstd::set<int>::iterator itr = mPressedKeys.find(key_code);
"""
KEYUP_NEW = f"""\tkey_code = TranslateKeyCode(key_code);
\tstd::set<int>::iterator itr = mPressedKeys.find(key_code);
\t// {MARKER}: consume the release so it cannot retrigger a GUI action.
\tif (key_code == KEY_VOLUMEUP || key_code == KEY_VOLUMEDOWN) {{
\t\tif (itr != mPressedKeys.end())
\t\t\tmPressedKeys.erase(itr);
\t\treturn 0;
\t}}
"""

if KEYDOWN_OLD not in source or KEYUP_OLD not in source:
    raise SystemExit("hardwarekeyboard.cpp anchors not found")
source = source.replace(KEYDOWN_OLD, KEYDOWN_NEW, 1)
source = source.replace(KEYUP_OLD, KEYUP_NEW, 1)
path.write_text(source, encoding="utf-8")
print(f"patched {path}")
