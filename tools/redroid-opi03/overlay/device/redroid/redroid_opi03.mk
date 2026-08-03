$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

# Use Android's Codec2 path.  The H618 hardware decoder is a vendor C2 store;
# keeping reDroid's generic OMX product would install a competing
# /vendor/etc/media_codecs.xml that never includes c2.allwinner.*.
REDROID_DISABLE_OMX := true
$(call inherit-product, $(LOCAL_PATH)/redroid.mk)
$(call inherit-product, $(LOCAL_PATH)/redroid_opi03/device.mk)

PRODUCT_NAME := redroid_opi03
PRODUCT_DEVICE := redroid_opi03
PRODUCT_BRAND := redroid
PRODUCT_MODEL := redroid12_opi03_h618
PRODUCT_MANUFACTURER := redroid

DEVICE_PACKAGE_OVERLAYS := $(LOCAL_PATH)/overlay
