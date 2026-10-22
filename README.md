# Xiaomi Pad 6 (pipa) recovery device tree

TWRP/OrangeFox-compatible device tree for **Xiaomi Pad 6** (`pipa`, SM8250).
The GitHub Actions workflow now follows the proven OrangeFox build flow on the
newer `fox_16.0` manifest:

## OrangeFox 16.0 编译

```bash
# 1) 使用 OrangeFox 官方同步脚本获取完整的 fox_16.0 manifest
git clone https://gitlab.com/OrangeFox/sync.git -b master
cd sync
./orangefox_sync.sh --branch 16.0 --path "$HOME/OrangeFox/fox_16.0"

# 2) 把本仓库放到 device/xiaomi/pipa
cd "$HOME/OrangeFox/fox_16.0"
git clone https://github.com/mengguizzz/twrp_device_xiaomi_pipa.git \
    device/xiaomi/pipa

# 3) 编译
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE=pipa
lunch twrp_pipa-bp2a-eng
make clean
mka adbd bootimage

# 4) 生成 fastboot boot 专用镜像
python3 device/xiaomi/pipa/tools/make_fbboot_image.py
```

`tools/patch_boot_header.py` 用来修正其它工具重打包出来的镜像的 boot header
（`os_version` / `os_patch_level`），用法见脚本头部注释。

## GitHub Actions

仓库包含 `.github/workflows/build-release.yml`。手动运行会构建并上传 workflow
artifact；推送 `orangefox-*` 标签或在手动运行中启用发布，会把 boot 镜像、fbboot
镜像、构建信息和 SHA-256 一并发布到 GitHub Release。

CI 直接使用 OrangeFox v032 同步脚本的 `16.0` 分支模式，不再叠加自定义最小化
manifest。主构建失败时会额外启动 `diagnose` job，下载完整 Actions 日志并上传，
以便分析 Runner 在 Soong 最后阶段失联的问题。
