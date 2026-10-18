#!/usr/bin/env python3
"""Add recovery_available to AOSP modules TWRP's recovery still links against."""
import os
from pathlib import Path
import sys

root = Path(
    sys.argv[1]
    if len(sys.argv) > 1
    else os.environ.get("TWRP_BUILD_DIR", os.getcwd())
).resolve()
TARGETS = [
    ('external/scrypt/Android.bp', 'libscrypt_static'),
    ('external/freetype/Android.bp', 'libft2'),
    ('system/keymaster/Android.bp', 'lib_android_keymaster_keymint_utils'),
]

for path, mod in TARGETS:
    p = root / path
    if not p.exists():
        sys.exit(f"missing file: {p}")
    s = p.read_text()
    key = 'name: "%s",' % mod
    i = s.find(key)
    if i < 0:
        sys.exit(f"module not found: {mod} in {path}")
    seg = s[max(0, i - 200):i + 800]
    if 'recovery_available' in seg:
        print('already patched:', mod)
        continue
    end = s.index('\n', i) + 1
    s = s[:end] + '    recovery_available: true,\n' + s[end:]
    p.write_text(s)
    print('patched', mod, 'in', path)
