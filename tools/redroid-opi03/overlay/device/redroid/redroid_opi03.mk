$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

# Stage 1 is Mali GPU only: disable reDroid's generic OMX product (its
# media_codecs.xml never includes c2.allwinner.*).  The Allwinner Codec2
# hardware decode path is deferred until the GPU renderer is verified.
REDROID_DISABLE_OMX := true
$(call inherit-product, $(LOCAL_PATH)/redroid.mk)
$(call inherit-product, $(LOCAL_PATH)/redroid_opi03/device.mk)

PRODUCT_NAME := redroid_opi03
PRODUCT_DEVICE := redroid_opi03
PRODUCT_BRAND := redroid
PRODUCT_MODEL := redroid12_opi03_h618
PRODUCT_MANUFACTURER := redroid

DEVICE_PACKAGE_OVERLAYS := $(LOCAL_PATH)/overlay
