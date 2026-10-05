# TWRP device tree — Xiaomi Pad 6 (pipa)

TWRP **3.7.1_16** device tree for **Xiaomi Pad 6** (`pipa`, SM8250), built on the
`twrp-16.0` manifest (AOSP `android-16.0.0_r1`, `BUILD_ID=BP2A.250605.031.A2`).

## 编译

```bash
# 1) 同步 twrp-16.0 manifest（TWRP 3.7.1_16 / AOSP 16）
repo init -u https://github.com/TeamWin/manifest -b twrp-16.0
repo sync -j8

# 2) 把本仓库放到 device/xiaomi/pipa

# 3) 应用 patches/ 里的源码补丁（少一个都编不过或功能不对）
python3 patches/ofox_patcher.py        # external/scrypt、external/freetype、system/keymaster 加 recovery_available
python3 patches/ofox_patch3.py         # android.system.keystore2 的 aidl_interface 加 recovery_available
cp patches/magisk-prebuilt_Android.bp external/magisk-prebuilt/Android.bp   # 原文件是 0 字节，A16 Soong 当致命错误

# 4) 主机依赖（否则 RecoveryImageGenerator 报 "Fontconfig head is null"）
sudo apt-get install -y fontconfig fonts-dejavu-core

# 5) 编译
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_pipa-bp2a-eng               # A16 需要 <product>-<release>-<variant> 三段式
mka bootimage -j$(nproc)               # -> out/target/product/pipa/boot.img

# 6) 生成 fastboot boot 专用镜像
python3 device/xiaomi/pipa/tools/make_fbboot_image.py
# -> out/target/product/pipa/boot-fbboot.img
```

`tools/patch_boot_header.py` 用来修正其它工具重打包出来的镜像的 boot header
（`os_version` / `os_patch_level`），用法见脚本头部注释。
