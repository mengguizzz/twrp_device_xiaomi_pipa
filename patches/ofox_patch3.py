#!/usr/bin/env python3
"""Two small patches so TWRP-16's recovery can resolve its crypto deps:

1. define the missing `resetprop_headers` header library that
   bootable/recovery/Android.bp expects from magisk-prebuilt;
2. try `recovery_available: true` on the android.system.keystore2 aidl_interface.
"""
import os
from pathlib import Path
import sys

root = Path(
    sys.argv[1]
    if len(sys.argv) > 1
    else os.environ.get("TWRP_BUILD_DIR", os.getcwd())
).resolve()

# ---- 1) resetprop_headers ------------------------------------------------
hdr_bp = root / 'external/magisk-prebuilt/Android.bp'
if hdr_bp.exists():
    print('Android.bp already exists, not touching')
else:
    hdr_bp.write_text('''// Added by the pipa TWRP-16 port.
//
// bootable/recovery/Android.bp (TWRP) lists "resetprop_headers" in header_libs
// when TW_INCLUDE_LIBRESETPROP is on, but the TeamWin android-12.1 copy of
// external/magisk-prebuilt only ships the .bp files under systemproperties/,
// utils/, prebuilt/, resetprop/ and external/ - the header library itself is
// missing (the top level Android.mk is empty).  Provide it here.
cc_library_headers {
    name: "resetprop_headers",
    recovery_available: true,
    export_include_dirs: [
        "include",
        "utils",
    ],
}
''')
    print('created', hdr_bp)

# ---- 2) keystore2 aidl recovery variant ---------------------------------
aidl = root / 'system/hardware/interfaces/keystore2/aidl/Android.bp'
if not aidl.exists():
    sys.exit(f"missing file: {aidl}")
s = aidl.read_text()
key = 'name: "android.system.keystore2",'
i = s.find(key)
if i < 0:
    sys.exit('keystore2 aidl_interface not found')
elif 'recovery_available' in s[i:i + 500]:
    print('already patched')
else:
    end = s.index('\n', i) + 1
    s = s[:end] + '    recovery_available: true,\n' + s[end:]
    aidl.write_text(s)
    print('patched', aidl)
