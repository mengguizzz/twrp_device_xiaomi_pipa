#
# Copyright (C) 2023 The Android Open Source Project
# Copyright (C) 2023 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/pipa

# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Android 14.1 validates external Soong plugins. OrangeFox recovery still
# registers these local plugins outside the framework allow-list.
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := kryo300

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a75

# Power
ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# Bootloader
PRODUCT_PLATFORM := kona
TARGET_BOOTLOADER_BOARD_NAME := kona
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true

# Platform
TARGET_BOARD_PLATFORM := kona
TARGET_BOARD_PLATFORM_GPU := qcom-adreno650
QCOM_BOARD_PLATFORMS += kona

# Kernel
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 3
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# Kernel - prebuilt
TARGET_FORCE_PREBUILT_KERNEL := true
ifeq ($(TARGET_FORCE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
endif

# Kernel dtb
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb

# A/B
BOARD_USES_RECOVERY_AS_BOOT := true
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    odm \
    product \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot

# Assert
TARGET_OTA_ASSERT_DEVICE := pipa

# AVB
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
# Partitions
# pipa uses a 192 MiB boot partition.  Keep this aligned with the boot image
# currently used by the port; 128 MiB causes modern OrangeFox ramdisks to be
# rejected or truncated during image creation.
BOARD_BOOTIMAGE_PARTITION_SIZE := 201326592
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
# Dynamic Partition
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
# BOARD_QTI_DYNAMIC_PARTITIONS_SIZ=BOARD_SUPER_PARTITION_SIZE - 2MB
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 9124708352
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := system product odm system_ext vendor

# System-as-root is the Android 14+ default. Do not set the removed legacy
# BOARD_BUILD_SYSTEM_ROOT_IMAGE flag: Android 14.1 rejects it.
BOARD_ROOT_EXTRA_FOLDERS := bluetooth dsp firmware persist
BOARD_SUPPRESS_SECURE_ERASE := true

# File systems
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_COPY_OUT_VENDOR := vendor

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888

# Display
TARGET_SCREEN_DENSITY := 400
TARGET_SCREEN_HEIGHT := 2880
TARGET_SCREEN_WIDTH := 1800
TW_FRAMERATE := 120
TARGET_RECOVERY_DEFAULT_ROTATION := ROTATION_RIGHT
TARGET_RECOVERY_DEFAULT_TOUCH_ROTATION := ROTATION_RIGHT

# Crypto
TW_INCLUDE_CRYPTO := true
# PLATFORM_VERSION is supplied by the selected Android release config.
# Do not override it here: the AP2A release is Android 14.
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# Tool
# TWRP-A16's Soong scanner rejects the legacy Android.mk in the upstream
# Magisk prebuilt project. Repack tools are not required to boot recovery or
# decrypt /data, so keep them disabled for this initial A16 compatibility test.
# TW_INCLUDE_REPACKTOOLS := true
# TW_INCLUDE_RESETPROP := true  # magisk-prebuilt Android.mk is blocked by A16 soong
# TW_INCLUDE_LIBRESETPROP := true  # same reason
TW_INCLUDE_LPDUMP := true
TW_INCLUDE_LPTOOLS := true

# TWRP Configuration
TW_THEME := portrait_hdpi
ifeq ($(TW_DEVICE_VERSION),)
TW_DEVICE_VERSION=16.0
endif
RECOVERY_SDCARD_ON_DATA := true
BOARD_HAS_NO_REAL_SDCARD := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXTRA_LANGUAGES := true
TW_INCLUDE_NTFS_3G := true
TARGET_USES_MKE2FS := true
TW_USE_TOOLBOX := true
TW_INPUT_BLACKLIST := hbtp_vm
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 200
TW_NO_SCREEN_BLANK := true
TW_EXCLUDE_APEX := true
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone1/temp"
TW_BATTERY_SYSFS_WAIT_SECONDS := 5
TW_BACKUP_EXCLUSIONS := /data/adb/ap,/data/adb/ksu

# Debug
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true

# Haptics
TW_NO_HAPTICS := true

# Serialno
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true

# The ported ColorOS 17 ROM was built as Android 17 (SDK 37) with platform
# security patch 2026-09-01.  The Keymaster TA stores os_version/os_patchlevel
# in the key blobs it creates: GetOsVersion() reads ro.build.version.release and
# GetOsPatchlevel()/GetVendorPatchlevel() read ro.build.version.security_patch
# and ro.vendor.build.security_patch.  A recovery built as Android 16 therefore
# reports an older os_version (160000 vs 170000), the TA answers
# KEY_REQUIRES_UPGRADE (-62) for the metadata key blob and the subsequent
# upgradeKey() fails with INVALID_ARGUMENT (-38), so /data cannot be decrypted.
# Rewrite those three properties in the recovery root right before the ramdisk
# is packed.

# ---- recovery image property overrides -------------------------------------
# (1) ro.build.version.* / security patches
#     The ported ColorOS 17 ROM is Android 17 (SDK 37, platform patch 2026-09-01).
#     Keymaster's TA stores os_version/os_patchlevel inside the key blobs it
#     creates: GetOsVersion() reads ro.build.version.release, GetOsPatchlevel()
#     reads ro.build.version.security_patch and GetVendorPatchlevel() reads
#     ro.vendor.build.security_patch. A recovery built as Android 16 reports an
#     older os_version (160000 vs 170000), so the TA answers
#     KEY_REQUIRES_UPGRADE (-62) for /metadata's keymaster_key_blob and the
#     following upgradeKey() fails with INVALID_ARGUMENT (-38) => /data can not
#     be decrypted (TWRP says 'wrong password').
# (2) twrp.drm.direct_scanout=0
#     The DRM scanout buffer is write-combined and TWRP's gGL renderer does
#     read-modify-write alpha blending, so drawing straight into the scanout
#     buffer reads uncached memory for every blended pixel. Measured while
#     scrolling a file list: 120 frames / 30 s (~4 fps, ~213 ms CPU per frame).
#     With direct scanout disabled TWRP draws into a cached buffer and only
#     copies the damage into the scanout buffer (write-only).
BOARD_RECOVERY_IMAGE_PREPARE = $(hide) sed -i \
    -e 's|^ro.build.version.release=.*|ro.build.version.release=17|' \
    -e 's|^ro.build.version.release_or_codename=.*|ro.build.version.release_or_codename=17|' \
    -e 's|^ro.build.version.release_or_preview_display=.*|ro.build.version.release_or_preview_display=17|' \
    -e 's|^ro.build.version.security_patch=.*|ro.build.version.security_patch=2026-09-01|' \
    -e 's|^ro.vendor.build.security_patch=.*|ro.vendor.build.security_patch=2026-09-01|' \
    -e 's|^twrp.drm.direct_scanout=.*|twrp.drm.direct_scanout=0|' \
    $(TARGET_RECOVERY_ROOT_OUT)/prop.default; \
    grep -q '^twrp.drm.direct_scanout=' $(TARGET_RECOVERY_ROOT_OUT)/prop.default || echo 'twrp.drm.direct_scanout=0' >> $(TARGET_RECOVERY_ROOT_OUT)/prop.default

# ---------------------------------------------------------------------------
# Boot image cmdline: do NOT put twrpfastboot=1 in the image we ship.
#
# This tree is built with BOARD_USES_RECOVERY_AS_BOOT := true, i.e. the boot
# image is the recovery ramdisk and is also the normal boot image. AOSP's
# first-stage init hands off to the installed system when the bootloader passes
# androidboot.force_normal_boot=1 (every normal boot), so the flashed image still
# boots ColorOS normally, and entering recovery (adb reboot recovery) boots TWRP.
#
# TWRP patched first-stage init so the cmdline flag twrpfastboot=1 disables that
# handoff. That flag is only wanted for the temporary image used with
# `fastboot boot` - if it were baked into the flashed image the device would
# always start into recovery and could not boot the ROM anymore. Generate that
# variant with:
#
#     python3 device/xiaomi/pipa/tools/make_fbboot_image.py
#
# (Historical note: BOARD_KERNEL_CMDLINE cannot be used here anyway -
# build/make/core/Makefile only appends --cmdline from INTERNAL_KERNEL_CMDLINE to
# INTERNAL_RECOVERYIMAGE_ARGS inside
#   ifneq (truetrue,$(strip $(BUILDING_VENDOR_BOOT_IMAGE))$(strip $(BOARD_USES_RECOVERY_AS_BOOT)))
# so with BOARD_USES_RECOVERY_AS_BOOT := true that block is skipped entirely.)
