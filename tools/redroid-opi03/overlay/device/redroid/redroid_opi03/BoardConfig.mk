# Keep reDroid's 64/32-bit ARM ABI and container partition layout, then replace
# only the board/GPU allocator contract with the H618 Android 12 BSP contract.
include device/redroid/redroid_arm64/BoardConfig.mk

# Allwinner H618 is called "apollo" by the Android 12 BSP.  These names must
# agree with the prebuilt Vulkan HAL (vulkan.apollo.so), Mali gralloc and the
# kernel's r20p0 Kbase ABI.
TARGET_BOARD_PLATFORM := apollo
TARGET_BOARD_HARDWARE := apollo
# cedarx_config.go reads the vendor "board" value to pick the platform cflags;
# without this, it falls back to default_cflags (-DCONF_ANDROID_MAJOR_VER=10)
# which collides with the Android 12 table entry (-D...=12) under -Werror.
$(call soong_config_add,vendor,board,$(TARGET_BOARD_PLATFORM))
# AOSP wifi_hal_common.cpp references DRIVER_MODULE_NAME unconditionally; the
# BSP boards define WIFI_DRIVER_MODULE_NAME and WIFI_DRIVER_MODULE_PATH so that
# the `#ifdef WIFI_DRIVER_MODULE_PATH` block declares DRIVER_MODULE_NAME.
# reDroid has no Wi-Fi HAL; placeholders are used only to compile the module.
WIFI_DRIVER_MODULE_NAME := dummy
WIFI_DRIVER_MODULE_PATH := dummy
TARGET_GPU_TYPE := mali-g31
TARGET_SUPPORTS_32_BIT_APPS := true
TARGET_USES_G2D := true
USE_IOMMU := true

# Allwinner's Gralloc 1.x module is loaded by Android's generic allocator 2.0
# wrapper.  Do not replace this with reDroid's GBM allocator: Mali-G31 uses
# /dev/mali0 rather than a DRM render node.
GRALLOC_API_VERSION := 1.x
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

include hardware/aw/gpu/product_config.mk
