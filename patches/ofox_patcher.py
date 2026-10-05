#!/usr/bin/env python3
"""Add recovery_available to AOSP modules TWRP's recovery still links against."""
import os
import subprocess
import sys

T = '/root/twrp16/'
TARGETS = [
    ('external/scrypt/Android.bp', 'libscrypt_static'),
    ('external/freetype/Android.bp', 'libft2'),
    ('system/keymaster/Android.bp', 'lib_android_keymaster_keymint_utils'),
]

for path, mod in TARGETS:
    p = T + path
    if not os.path.exists(p):
        print('missing file:', p)
        continue
    s = open(p).read()
    key = 'name: "%s",' % mod
    i = s.find(key)
    if i < 0:
        print('module not found:', mod, 'in', path)
        continue
    seg = s[max(0, i - 200):i + 800]
    if 'recovery_available' in seg:
        print('already patched:', mod)
        continue
    end = s.index('\n', i) + 1
    s = s[:end] + '    recovery_available: true,\n' + s[end:]
    open(p, 'w').write(s)
    print('patched', mod, 'in', path)
