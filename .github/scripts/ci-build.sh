#!/bin/bash
set -eEuo pipefail

SOURCE_REPO=${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}
BUILD_DIR=${TWRP_BUILD_DIR:-/mnt/twrp-ci/src}
RELEASE_DIR=${TWRP_RELEASE_DIR:-/mnt/twrp-ci/release}
DIAG_DIR=${TWRP_DIAG_DIR:-$SOURCE_REPO/.ci/diagnostics}
CCACHE_DIR=${CCACHE_DIR:-$BUILD_DIR/.ccache}
SYNC_JOBS=${SYNC_JOBS:-4}
BUILD_JOBS=${BUILD_JOBS:-$(nproc)}
MIN_FREE_GB=${MIN_FREE_GB:-45}
MANIFEST_URL=${TWRP_MANIFEST_URL:-https://github.com/ymdzq/manifest_twrp.git}
MANIFEST_BRANCH=${TWRP_MANIFEST_BRANCH:-twrp-16.0}
BUILD_LABEL=${BUILD_LABEL:-twrp_pipa_A16_${GITHUB_RUN_NUMBER:-local}_${GITHUB_SHA:0:8}}
DEVICE_DIR="$BUILD_DIR/device/xiaomi/pipa"
OUT_DIR="$BUILD_DIR/out/target/product/pipa"

export PATH="$HOME/.local/bin:$PATH"
export CCACHE_DIR

mkdir -p "$BUILD_DIR/.tmp" "$BUILD_DIR/.cache/go-build" \
    "$RELEASE_DIR" "$DIAG_DIR" "$CCACHE_DIR"

# Keep a copy of stdout/stderr in the diagnostics artifact, not only in the
# Actions log. This makes ordinary script failures inspectable from the API.
exec > >(tee -a "$DIAG_DIR/build.log") 2>&1

# The maximize-build-space action mounts the large volume at the workspace,
# while / can be intentionally tiny after that action. Keep temporary files
# on the large build volume, but use a short /tmp symlink as their entry point:
# repo's Python multiprocessing sockets have a 108-byte AF_UNIX path limit.
SHORT_TMP="/tmp/twrp-ci-${GITHUB_RUN_ID:-$$}"
ln -s "$BUILD_DIR/.tmp" "$SHORT_TMP"
export TMPDIR="$SHORT_TMP"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
export GOCACHE="$BUILD_DIR/.cache/go-build"
export GOTMPDIR="$TMPDIR"
export CCACHE_TEMPDIR="$BUILD_DIR/.cache/ccache-tmp"
mkdir -p "$CCACHE_TEMPDIR"

echo "Build paths:"
echo "  source=$SOURCE_REPO"
echo "  build=$BUILD_DIR"
echo "  release=$RELEASE_DIR"
echo "  diagnostics=$DIAG_DIR"
echo "  TMPDIR=$TMPDIR"
echo "  sync_jobs=$SYNC_JOBS build_jobs=$BUILD_JOBS"

RESOURCE_LOG="$DIAG_DIR/resources.log"
FAILURE_LOG="$DIAG_DIR/failure.log"
record_resources() {
    local tick=0
    while kill -0 $$ 2>/dev/null; do
        local mem swap root_avail build_avail top_proc now
        mem=$(free -m | awk '/^Mem:/ { print $3 "/" $2 }')
        swap=$(free -m | awk '/^Swap:/ { print $3 "/" $2 }')
        root_avail=$(df -Pm / | awk 'NR == 2 { print $4 }')
        build_avail=$(df -Pm "$BUILD_DIR" | awk 'NR == 2 { print $4 }')
        top_proc=$(ps -eo pid,ppid,pmem,rss,comm --sort=-rss | sed -n '2p')
        now=$(date -u +%FT%TZ)
        {
            printf '%s mem=%sMiB swap=%sMiB root_avail=%sMiB build_avail=%sMiB top="%s"\n' \
                "$now" "$mem" "$swap" "$root_avail" "$build_avail" "$top_proc"
            df -h / "$BUILD_DIR"
            free -h
            ps -eo pid,ppid,pmem,rss,comm --sort=-rss | head -15
        } >> "$RESOURCE_LOG"

        # Keep a compact timeline in the Actions log too. If the runner is
        # terminated, these are the last visible resource measurements.
        if (( tick % 2 == 0 )); then
            echo "RESOURCE $now mem=${mem}MiB swap=${swap}MiB root_avail=${root_avail}MiB build_avail=${build_avail}MiB top=${top_proc}"
        fi
        tick=$((tick + 1))
        sleep 30
    done
}

record_resources &
RESOURCE_MONITOR_PID=$!
cleanup() {
    local status=$?
    trap - EXIT
    kill "$RESOURCE_MONITOR_PID" 2>/dev/null || true
    if (( status != 0 )); then
        {
            echo "exit_status=$status"
            date -u
            df -h / "$BUILD_DIR"
            free -h
            ps -eo pid,ppid,pmem,rss,comm --sort=-rss | head -30
            sudo dmesg --ctime | tail -200 || true
        } > "$FAILURE_LOG" 2>&1
    fi
    exit "$status"
}
trap cleanup EXIT

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
    if repo sync -c -j"$SYNC_JOBS" --no-clone-bundle --no-tags --fail-fast; then
        break
    fi
    if (( attempt == 3 )); then
        echo "repo sync failed after three attempts" >&2
        exit 1
    fi
    echo "repo sync failed; retrying in 15 seconds (${attempt}/3)"
    sleep 15
done

echo "Synced projects: $(repo list --path-only | wc -l)"

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

sync
df -h "$BUILD_DIR"
free -h

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
