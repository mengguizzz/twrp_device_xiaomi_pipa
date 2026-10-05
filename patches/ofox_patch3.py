#!/usr/bin/env python3
"""Two small patches so TWRP-16's recovery can resolve its crypto deps:

1. define the missing `resetprop_headers` header library that
   bootable/recovery/Android.bp expects from magisk-prebuilt;
2. try `recovery_available: true` on the android.system.keystore2 aidl_interface.
"""
import os

T = '/root/twrp16/'

# ---- 1) resetprop_headers ------------------------------------------------
hdr_bp = T + 'external/magisk-prebuilt/Android.bp'
if os.path.exists(hdr_bp):
    print('Android.bp already exists, not touching')
else:
    with open(hdr_bp, 'w') as f:
        f.write('''// Added by the pipa TWRP-16 port.
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
aidl = T + 'system/hardware/interfaces/keystore2/aidl/Android.bp'
s = open(aidl).read()
key = 'name: "android.system.keystore2",'
i = s.find(key)
if i < 0:
    print('keystore2 aidl_interface not found')
elif 'recovery_available' in s[i:i + 500]:
    print('already patched')
else:
    end = s.index('\n', i) + 1
    s = s[:end] + '    recovery_available: true,\n' + s[end:]
    open(aidl, 'w').write(s)
    print('patched', aidl)
