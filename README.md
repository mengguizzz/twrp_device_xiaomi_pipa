# TWRP device tree — Xiaomi Pad 6 (pipa)

TWRP **3.7.1_16** device tree for **Xiaomi Pad 6** (`pipa`, SM8250), built on the
`twrp-16.0` manifest (AOSP `android-16.0.0_r1`, `BUILD_ID=BP2A.250605.031.A2`).

## 编译

```bash
# 1) 同步 twrp-16.0 manifest（TWRP 3.7.1_16 / AOSP 16）
repo init -u https://github.com/ymdzq/manifest_twrp.git -b twrp-16.0
repo sync -j8

# 2) 把本仓库放到 device/xiaomi/pipa

# 3) 应用全部源码补丁（可从源码树根目录运行，也可传入源码树路径）
bash device/xiaomi/pipa/patches/apply_all.sh "$PWD"
# 包括 magisk-prebuilt 的 Android.bp 替代，并禁用会被 A16 Soong 拒绝的 Android.mk

# 4) 主机依赖（否则 RecoveryImageGenerator 报 "Fontconfig head is null"）
bash device/xiaomi/pipa/.github/scripts/install-deps.sh

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

## GitHub Actions

仓库包含 `.github/workflows/build-release.yml`。手动运行会构建并上传 workflow
artifact；推送 `twrp-*` 标签或在手动运行中启用发布，会把 boot 镜像、fbboot
镜像、构建信息和 SHA-256 一并发布到 GitHub Release。

CI 使用 `patches/apply_all.sh` 以便携方式应用所有源码补丁，并把源码和输出放在
GitHub Hosted Runner 的 `/mnt` 大容量临时盘上。详细说明见
`.github/workflows/README.md`。

CI 同时使用 OrangeFox 的固定版本 `remove-minimal.xml` 作为 repo local manifest，
移除非 recovery 所需的完整 AOSP 项目，避免 Hosted Runner 在 Soong 后段耗尽磁盘。
