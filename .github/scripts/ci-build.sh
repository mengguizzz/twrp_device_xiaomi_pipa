#!/bin/bash
set -euo pipefail

SOURCE_REPO=${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}
BUILD_DIR=${TWRP_BUILD_DIR:-/mnt/twrp-ci/src}
RELEASE_DIR=${TWRP_RELEASE_DIR:-/mnt/twrp-ci/release}
CCACHE_DIR=${CCACHE_DIR:-$HOME/.cache/ccache/twrp16}
BUILD_JOBS=${BUILD_JOBS:-$(nproc)}
MIN_FREE_GB=${MIN_FREE_GB:-45}
MANIFEST_URL=${TWRP_MANIFEST_URL:-https://github.com/ymdzq/manifest_twrp.git}
MANIFEST_BRANCH=${TWRP_MANIFEST_BRANCH:-twrp-16.0}
BUILD_LABEL=${BUILD_LABEL:-twrp_pipa_A16_${GITHUB_RUN_NUMBER:-local}_${GITHUB_SHA:0:8}}
DEVICE_DIR="$BUILD_DIR/device/xiaomi/pipa"
OUT_DIR="$BUILD_DIR/out/target/product/pipa"

export PATH="$HOME/.local/bin:$PATH"
export CCACHE_DIR

mkdir -p "$BUILD_DIR" "$RELEASE_DIR" "$CCACHE_DIR"

free_gb=$(df -Pk "$BUILD_DIR" | awk 'NR == 2 { printf "%d", $4 / 1024 / 1024 }')
if (( free_gb < MIN_FREE_GB )); then
    echo "Not enough free space: ${free_gb} GiB, need at least ${MIN_FREE_GB} GiB" >&2
    exit 1
fi

git config --global user.name  >/dev/null 2>&1 || \
    git config --global user.name "pipa CI"
git config --global user.email >/dev/null 2>&1 || \
    git config --global user.email "pipa-ci@localhost"

cd "$BUILD_DIR"

if [ ! -d "$BUILD_DIR/.repo" ]; then
    repo init \
        --depth=1 \
        --partial-clone \
        --clone-filter=blob:limit=1m \
        -u "$MANIFEST_URL" \
        -b "$MANIFEST_BRANCH"
fi

for attempt in 1 2 3; do
    if repo sync -c -j"$BUILD_JOBS" --no-clone-bundle --no-tags --fail-fast; then
        break
    fi
    if (( attempt == 3 )); then
        echo "repo sync failed after three attempts" >&2
        exit 1
    fi
    echo "repo sync failed; retrying in 15 seconds (${attempt}/3)"
    sleep 15
done

rm -rf "$DEVICE_DIR"
mkdir -p "$(dirname "$DEVICE_DIR")"
rsync -a --delete \
    --exclude=.git \
    --exclude=.ci \
    --exclude=.ccache \
    "$SOURCE_REPO/" "$DEVICE_DIR/"

bash "$DEVICE_DIR/patches/ofox_fix_crlf.sh" "$DEVICE_DIR"
bash "$DEVICE_DIR/patches/apply_all.sh" "$BUILD_DIR"

if grep -rIl $'\r' \
    "$DEVICE_DIR/recovery/root/system/etc/recovery.fstab" \
    "$DEVICE_DIR/recovery/root/system/etc/twrp.flags"; then
    echo "Recovery config files still contain CRLF" >&2
    exit 1
fi

ccache --max-size="${CCACHE_MAX_SIZE:-4G}"
ccache --zero-stats

export ALLOW_MISSING_DEPENDENCIES=true
export USE_CCACHE=1
CCACHE_EXEC=$(command -v ccache)
export CCACHE_EXEC
export CCACHE_BASEDIR="$BUILD_DIR"
export CCACHE_NOHASHDIR=true
export CCACHE_SLOPPINESS=time_macros,file_macro

# Soong's sandbox prevents the ccache action's compiler wrapper from working.
sed -i 's/return sandboxConfig\.working/return false/g' \
    build/soong/ui/build/sandbox_linux.go

set +u
source build/envsetup.sh
if ! lunch twrp_pipa-bp2a-eng; then
    echo "lunch failed; collecting product diagnostics" >&2
    ls -l "$DEVICE_DIR/AndroidProducts.mk" "$DEVICE_DIR/twrp_pipa.mk" >&2
    grep -n "COMMON_LUNCH_CHOICES\\|PRODUCT_MAKEFILES" \
        "$DEVICE_DIR/AndroidProducts.mk" >&2 || true
    TARGET_PRODUCT=twrp_pipa TARGET_RELEASE=bp2a TARGET_BUILD_VARIANT=eng \
        _get_build_var_cached TARGET_DEVICE || true
    exit 1
fi
set -u

renice -n 5 -p $$ >/dev/null || true
mka bootimage -j"$BUILD_JOBS"

BOOTIMAGE="$OUT_DIR/boot.img"
if [ ! -f "$BOOTIMAGE" ]; then
    echo "Missing build output: $BOOTIMAGE" >&2
    exit 1
fi

RELEASE_BOOT="$RELEASE_DIR/${BUILD_LABEL}_boot.img"
RELEASE_FBBOOT="$RELEASE_DIR/${BUILD_LABEL}_fbboot.img"
cp "$BOOTIMAGE" "$RELEASE_BOOT"
python3 "$DEVICE_DIR/tools/make_fbboot_image.py" \
    "$RELEASE_BOOT" "$RELEASE_FBBOOT"

python3 - "$RELEASE_BOOT" <<'PY'
import struct
import sys

path = sys.argv[1]
with open(path, "rb") as image:
    header = image.read(4096)

if header[:8] != b"ANDROID!":
    raise SystemExit("boot image magic is invalid")
if struct.unpack_from("<I", header, 0x28)[0] != 3:
    raise SystemExit("unexpected boot header version")
if struct.unpack_from("<I", header, 0x10)[0] != 0x2000063C:
    raise SystemExit("unexpected os_version/os_patch_level")
if header[0x2C:0x2C + 512].split(b"\0", 1)[0]:
    raise SystemExit("flashed boot image has a non-empty cmdline")
PY

grep -q '^ro.color597.product_name=Xiaomi Pad 6$' \
    "$OUT_DIR/recovery/root/prop.default"

{
    echo "device=pipa"
    echo "manifest=$MANIFEST_URL:$MANIFEST_BRANCH"
    echo "device_tree_commit=${GITHUB_SHA:-unknown}"
    echo "workflow_run=${GITHUB_SERVER_URL:-local}/${GITHUB_REPOSITORY:-unknown}/actions/runs/${GITHUB_RUN_ID:-local}"
    echo "kernel_sha256=$(sha256sum "$OUT_DIR/kernel" | awk '{print $1}')"
    echo "boot_sha256=$(sha256sum "$RELEASE_BOOT" | awk '{print $1}')"
    echo "fbboot_sha256=$(sha256sum "$RELEASE_FBBOOT" | awk '{print $1}')"
} > "$RELEASE_DIR/BUILD_INFO.txt"

(
    cd "$RELEASE_DIR"
    sha256sum ./*.img > SHA256SUMS.txt
)

ccache --show-stats
file "$RELEASE_BOOT" "$RELEASE_FBBOOT"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "release_dir=$RELEASE_DIR" >> "$GITHUB_OUTPUT"
    echo "build_label=$BUILD_LABEL" >> "$GITHUB_OUTPUT"
fi
