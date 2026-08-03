PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true

# The Codec2 binary links the CedarX front-end directly, but the codec engines
# (libawh264, libawh265, VP9, MPEG variants, cedarc.conf, and their vendor
# variants) are selected by Allwinner's product list.  They are not all pulled
# into an image merely because the service links libvdecoder.  The exact-board
# Android 12 product inherits this same list through softwinner/common.mk.
$(call inherit-product, frameworks/av/media/libcedarc/libcdclist.mk)

# gpu-package installs the matching libGLES_mali.so, vulkan.apollo.so and
# gralloc.apollo.  The Allwinner Codec2 service links CedarX and opens
# /dev/cedar_dev through the vendor libVE/libvdecoder stack.
PRODUCT_PACKAGES += \
    gpu-package \
    android.hardware.media.aw.c2@1.0-service \
    stagefright

OPI03_CODEC_CONFIG := device/softwinner/apollo/common/media/codec
PRODUCT_COPY_FILES += \
    vendor/redroid_opi03/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(OPI03_CODEC_CONFIG)/media_codecs_allwinner_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_allwinner_video.xml \
    $(OPI03_CODEC_CONFIG)/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    $(OPI03_CODEC_CONFIG)/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml \
    $(OPI03_CODEC_CONFIG)/media_codecs_performance.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_performance.xml \
    $(OPI03_CODEC_CONFIG)/mediacodec-arm.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy \
    vendor/redroid_opi03/redroid.opi03.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/redroid.opi03.rc

PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.egl=mali \
    ro.hardware.gralloc=apollo \
    ro.hardware.vulkan=apollo
