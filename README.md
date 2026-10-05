# TWRP device tree — Xiaomi Pad 6 (pipa)

TeamWin Recovery Project (**TWRP 3.7.1_16**) device tree for **Xiaomi Pad 6**
(`pipa`, SM8250 / kona), built on the **`twrp-16.0` manifest
(AOSP `android-16.0.0_r1`, `BUILD_ID=BP2A.250605.031.A2`)**.

The tree started from the OrangeFox-based pipa tree and has been reworked so that
recovery boots on — and **decrypts /data of** — the **ColorOS 17 / Android 17 port**
for pipa. Everything below was verified on the device.

> This is a *TeamWin* (TWRP) tree. It is **not** an OrangeFox tree.

---

## Build

```bash
# manifest: twrp-16.0 (TWRP 3.7.1_16 / AOSP 16)
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_pipa-bp2a-eng        # note the 3-segment lunch target (see AndroidProducts.mk)
mka bootimage -j$(nproc)
# -> out/target/product/pipa/boot.img  (recovery-in-boot, ~192 MB)
```

Host packages needed on top of the usual AOSP build deps: `fontconfig
fonts-dejavu-core` (otherwise `RecoveryImageGenerator` aborts with
`Fontconfig head is null`).

### Flashing / booting notes (pipa, ColorOS 17 port)

* This tree is built with `BOARD_USES_RECOVERY_AS_BOOT := true`: the boot image *is*
  the recovery ramdisk and is also the normal boot image.
* The build adds **`twrpfastboot=1` to the boot header cmdline**
  (`BOARD_KERNEL_CMDLINE += twrpfastboot=1`, see `BoardConfig.mk`), exactly like every
  other pipa recovery image (OrangeFox R11.3/R12.0, twrp-last). TWRP patched
  `system/core/init/first_stage_init.cpp` so that this flag **disables** the
  `androidboot.force_normal_boot` hand-off to the installed system — which is what a
  normal boot (and `fastboot boot`) would otherwise do. Therefore:

  ```bash
  fastboot boot boot.img            # boots TWRP directly (temporary, nothing flashed)
  fastboot flash boot_b boot.img    # TWRP installed; device then always starts into recovery
  ```

  ⚠️ While this image is installed in the boot partition the ROM does **not** boot
  (that is the trade-off of the flag). Flash back the ROM's `boot.img` (or any
  flag-free boot image) to boot ColorOS again — that is also how the previous
  OrangeFox/twrp-last images behave.

---

## Local modifications (relative to the tree we started from)

| File | Change | Why |
|---|---|---|
| `BoardConfig.mk` | `TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888` **without quotes** | quoted value ended up as `""RGBX_8888""` in the Soong JSON and failed the build |
| `BoardConfig.mk` | `TW_INPUT_BLACKLIST := hbtp_vm` **without quotes** | same reason; also a no-op on pipa (that input device does not exist here) |
| `BoardConfig.mk` | new `BOARD_RECOVERY_IMAGE_PREPARE` hook that rewrites `$(TARGET_RECOVERY_ROOT_OUT)/prop.default` (see “property hook” below) | keymaster version match + DRM performance |
| `BoardConfig.mk` | `TW_INCLUDE_RESETPROP` / `TW_INCLUDE_LIBRESETPROP` disabled | the tree’s `external/magisk-prebuilt/Android.mk` is a 0-byte file and A16 Soong treats that as a fatal error |
| `BoardConfig.mk` | `BOARD_KERNEL_CMDLINE += twrpfastboot=1` | makes `fastboot boot` enter TWRP instead of handing off to the ROM (see “Flashing / booting notes”); all pipa recovery images do this |
| all text files under this tree | **CRLF → LF** (`recovery.fstab` had 68 CRLF lines) | A16’s `libfstab` splits on `\n` and tokenises on ` \t`; the leftover `\r` makes empty lines a single `"\r"` token → `expected 5 fields, got 1` → `abort()` in recovery. A12-based recoveries were tolerant, which is why the old images worked |
| `recovery/root/system/etc/recovery.fstab` | `/boot` and `/dtbo` got the **`slotselect`** flag; removed the bogus `/exaid` entry and the `mi_ext` entry; added `/vendor_boot` and `/vbmeta` | the device has **no plain `by-name/boot`** (only `boot_a`/`boot_b`), so TWRP’s *Install Recovery Ramdisk* aborted at “Backing up Boot…” with `Error opening: '' (No such file or directory)`. The same applies to `dtbo`. `exaid` does not exist on pipa and this ROM’s super has no `mi_ext` logical partition (TWRP logged `unable to update logical partition: /mi_ext`). Checked every entry against the ROM’s own `vendor/etc/fstab.qcom` and the device’s `by-name` table |

### TWRP source patch: `/etc/twrp.flags` parser (`patches/ofox_patch_twrpflags.py`)

*Fix for “Install Recovery Ramdisk” still failing after the fstab fix.*

`/etc/twrp.flags` uses the TWRP v1 layout

```
<mount point>  <fstype>  <device>  [<device2>]  flags=<...>
```

but `parse_twrp_flags()` in `bootable/recovery/partitionmanager.cpp` read the
**fstype** (`emmc`/`ext4`) as `Primary_Block_Device`, and
`Override_Block_Devices_From_Flags()` then overwrote the real device parsed from
`/etc/recovery.fstab` with it. For `/boot` and `/dtbo` — whose nodes only exist as
`boot_b`/`dtbo_b`, there is no unsuffixed `by-name/boot` — that left
`Actual_Block_Device` empty, so the backup before repacking aborted:

```
Backing up Boot...
Error opening: '' (No such file or directory)
```

(Other partitions survived only because their unsuffixed `by-name/<name>` node
exists, so the alternate path fallback still worked.)

The patch makes the parser read the device from `tokens[2]`, the filesystem from
`tokens[1]` and look for an alternate device from `tokens[3]` on. Apply it with
`patches/ofox_patch_twrpflags.py` after syncing `twrp-16.0`.
| `device.mk` | dropped `TWRP_REQUIRED_MODULES += miui_prebuilt` | same magisk-prebuilt problem; the MIUI repack feature is not needed |
| `AndroidProducts.mk` | added 3-segment `.mk` entries (`twrp_pipa-bp2a-eng`, `-user`, `-userdebug`) | A16 `lunch` requires `<product>-<release>-<variant>` |
| `recovery/root/init.recovery.qcom.rc` | added `on early-init / write /sys/fs/selinux/enforce 0` | with SELinux enforcing the AIDL boot HAL (`hal_bootctl_default`) cannot `stat /dev/block/bootdevice/by-name/misc`, never registers, and TWRP blocks forever at `Processing /etc/recovery.fstab`; HIDL keymaster/gatekeeper are also affected |
| `recovery/root/init.recovery.qcom.rc` | removed `start boot-hal-1-1` | that HIDL boot stub has no passthrough implementation on this device, exits 1 every 5 s; after 4 crashes init does `LOG(FATAL) "critical process … exited 4 times"` → sysrq crash → the device panics/reboots ~22 s after boot |
| `recovery/root/system/etc/vintf/manifest/boot-service.qti.xml` (**new**) | declares `android.hardware.boot.IBootControl/default` with `type="framework"` | the recovery ramdisk shipped inside the ROM’s `vendor_boot` puts a **device-typed** fragment with the same name into `/system/etc/vintf/manifest/`, which aborts `hwservicemanager`’s *framework* manifest parse; it then sets `hwservicemanager.disabled=true` and exits, so all HIDL clients (keymaster!) fail to register. Our ramdisk wins the merge, and a framework-typed fragment keeps both parsers happy (the recovery manifest reader force-casts fragments to DEVICE anyway) |
| `recovery/root/vendor/etc/vintf/manifest/android.hardware.health@2.1.xml` (**new**) | HIDL `android.hardware.health@2.1` device fragment | `android.hardware.health@2.1-service` could not register (`must be in VINTF manifest`) and crash-looped every 5 s |
| `prebuilt/kernel` | replaced with our port’s kernel (`4.19.325-cip…`, 38,971,416 B) | must match the ROM’s kernel (SukiSU-Ultra + SUSFS built in) |
| `recovery/root/vendor/lib64/libqtikeymaster4.so`, `libkeymasterdeviceutils.so`, `recovery/root/vendor/bin/qseecomd` | replaced with the copies from the port’s real `vendor` | recovery must use the same QTI keymaster implementation as the ROM, otherwise the TEE refuses the key blobs |
| `recovery/root/.../android.hardware.keymaster@4.1-*` | removed (binary + VINTF + `init.recovery.qcom.rc` service) | the device has no 4.1 HAL |

### The `prop.default` hook (`BOARD_RECOVERY_IMAGE_PREPARE`)

Runs right before the recovery ramdisk is packed (`build/make/core/Makefile`) and
writes four properties into `$(TARGET_RECOVERY_ROOT_OUT)/prop.default`:

```properties
ro.build.version.release=17
ro.build.version.security_patch=2026-09-01
ro.vendor.build.security_patch=2026-09-01
twrp.drm.direct_scanout=0
```

1. **Version properties** — the keymaster TA stores `os_version` / `os_patchlevel`
   inside every key blob. The service derives them from
   `ro.build.version.release` (`GetOsVersion()`),
   `ro.build.version.security_patch` (`GetOsPatchlevel()`) and
   `ro.vendor.build.security_patch` (`GetVendorPatchlevel()`) —
   `system/keymaster/android_keymaster/keymaster_configuration.cpp`.
   `/metadata`’s `keymaster_key_blob` was created by ColorOS 17
   (Android 17, patch `2026-09-01`). A recovery reporting Android 16 makes the TA
   answer `KEY_REQUIRES_UPGRADE (-62)` and the following `upgradeKey()` fails with
   `INVALID_ARGUMENT (-38)` (a *downgrade* is not allowed), so TWRP reports
   “wrong password”. With the values above, decryption works:

   ```
   I:Keymaster_Ver::Using keymaster version '4.x' for decryption
   I:Successfully decrypted metadata encrypted data partition with new block device: '/dev/block/dm-5'
   # twrp decrypt <password>
   User 0 Decrypted Successfully!
   Data successfully decrypted
   ```

   (Data created by an *older* Android release would be a *newer* current version,
   i.e. a legal upgrade; data created by a *newer* release than these values would
   still fail — change these three lines in that case.)

2. **`twrp.drm.direct_scanout=0`** — the DRM scanout buffer is write-combined and
   TWRP’s gGL renderer does read-modify-write alpha blending, so drawing directly
   into the scanout buffer reads uncached memory for every blended pixel.
   Measured while scrolling a file list with `twrp.drm.stats=1`:

   | | direct scanout (default) | `direct_scanout=0` |
   |---|---|---|
   | frames | 120 / 30 s ≈ **4 fps** | smooth |
   | CPU | ~213 ms per frame (85 % of one core) | low |
   | copied per frame | ~11.5 MB into the scanout buffer | damage only, write-only |

---

## Patches that live *outside* this device tree

They are in `patches/` for reference:

| Where | Patch |
|---|---|
| `external/magisk-prebuilt/Android.bp` (**new file**) | defines `resetprop_headers` (`cc_library_headers`, `export_include_dirs: ["include","utils"]`) because the tree only ships an empty `Android.mk` |
| `external/scrypt`, `external/freetype`, `system/keymaster` | add `recovery_available: true` to `libscrypt_static`, `libft2`, `lib_android_keymaster_keymint_utils` |
| `system/hardware/interfaces/keystore2/aidl/Android.bp` | add `recovery_available: true` to the `android.system.keystore2` `aidl_interface` |

Apply them with `patches/ofox_patcher.py`, `patches/ofox_patch3.py`
(and `patches/magisk-prebuilt_Android.bp`), then build as shown above.

---

## Verified

* TWRP boots with the A16 build, UI comes up, `adb` available.
* `/data` metadata encryption **and** FBE user 0 decrypt successfully
  (`twrp decrypt <password>` → `Data successfully decrypted`), `/sdcard` mounts.
* `hwservicemanager`, `keymaster@4.0`, `keystore2`, AIDL `vendor.boot-qti`,
  `health@2.1` all `running` (no crash loops).
* File-list scrolling is smooth after the `direct_scanout` change.

## Known issues

* `pigz: abort: write error on <stdout> (No space left on device)` — the device’s
  `/cache` partition was 100 % full; clear cache. Unrelated to the recovery.
* `E:Unable to load '/twres/languages/en_US.xml'` — falls back to `en.xml`.
* `/mi_ext` shows as a 0 B partition (TWRP does not know that logical partition).
* Recovery runs SELinux in permissive mode (see `init.recovery.qcom.rc`).
