PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true

# Stage 1 goal: drive the Mali-G31 GPU inside the reDroid container.  The
# Allwinner hardware video decode path (Codec2/CedarX) is deliberately deferred:
# the vendor libcedarc 64-bit blobs are Linux glibc/musl builds, not Android
# bionic, so linking them fails Android's check_elf_files.  Once the Mali
# renderer is verified on device, re-enable the Codec2 service and its
# libcdclist/codec XML as a separate step.

# gpu-package installs the matching libGLES_mali.so, vulkan.apollo.so and
# gralloc.apollo; it is independent of the CedarX video stack.  gralloc.apollo
# is built from source and pulled in by gpu-package, but the prebuilt
# libGLES_mali/vulkan copy targets are not registered under the reDroid arm64
# board, so copy them explicitly.
PRODUCT_PACKAGES += \
    gpu-package

PRODUCT_COPY_FILES += \
    hardware/aw/gpu/mali-bifrost/mali-g31/arm64/lib/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/libGLES_mali.so \
    hardware/aw/gpu/mali-bifrost/mali-g31/arm64/lib/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/vulkan.apollo.so \
    hardware/aw/gpu/mali-bifrost/mali-g31/arm64/lib64/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLES_mali.so \
    vendor/redroid_opi03/redroid.opi03.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/redroid.opi03.rc

PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.egl=mali \
    ro.hardware.gralloc=apollo \
    ro.hardware.vulkan=apollo
