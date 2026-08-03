#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 /path/to/android-root [output.tar.zst]" >&2
  exit 2
fi

android_root=$(cd -- "$1" && pwd)
product_out="$android_root/out/target/product/redroid_opi03"
output=${2:-"$android_root/opi03-redroid-android12-h618-rootfs.tar.zst"}

for image in system.img vendor.img; do
  if [[ ! -f "$product_out/$image" ]]; then
    echo "missing $product_out/$image; build redroid_opi03 first" >&2
    exit 1
  fi
done

work_dir=$(mktemp -d)
mkdir -p "$work_dir/system" "$work_dir/vendor"

cleanup() {
  if mountpoint -q "$work_dir/vendor"; then
    sudo umount "$work_dir/vendor"
  fi
  if mountpoint -q "$work_dir/system"; then
    sudo umount "$work_dir/system"
  fi
  rmdir "$work_dir/vendor" "$work_dir/system" "$work_dir" 2>/dev/null || true
}
trap cleanup EXIT

sudo mount -o loop,ro "$product_out/system.img" "$work_dir/system"
sudo mount -o loop,ro "$product_out/vendor.img" "$work_dir/vendor"

# Fail before spending time compressing and transferring an image whose
# product makefiles only advertised the accelerator HALs but omitted their
# runtime payload.  Allwinner's Codec2 service is 32-bit on this BSP, while
# SurfaceFlinger also needs the 64-bit Mali userspace.
required_vendor_files=(
  bin/hw/android.hardware.media.aw.c2@1.0-service
  etc/cedarc.conf
  etc/init/android.hardware.media.aw.c2@1.0-service.rc
  etc/init/redroid.opi03.rc
  etc/media_codecs.xml
  etc/media_codecs_allwinner_video.xml
  lib/egl/libGLES_mali.so
  lib/hw/gralloc.apollo.so
  lib/libawh264.so
  lib/libawh265.so
  lib64/egl/libGLES_mali.so
  lib64/hw/gralloc.apollo.so
)

for relative_path in "${required_vendor_files[@]}"; do
  if [[ ! -e "$work_dir/vendor/$relative_path" ]]; then
    echo "incomplete opi03 Android vendor image; missing: /vendor/$relative_path" >&2
    exit 1
  fi
done

if ! grep -qF 'media_codecs_allwinner_video.xml' "$work_dir/vendor/etc/media_codecs.xml"; then
  echo "primary media_codecs.xml does not include the Allwinner Codec2 list" >&2
  exit 1
fi

if ! grep -RqsF '<name>android.hardware.media.c2</name>' "$work_dir/vendor/etc/vintf"; then
  echo "Allwinner Codec2 VINTF fragment is missing from the vendor image" >&2
  exit 1
fi

temporary_output="${output}.partial"
rm -f -- "$temporary_output"
(
  cd "$work_dir"
  # Match the official reDroid image layout: the system image is the container
  # root and the separately built vendor image becomes /vendor.
  sudo tar --xattrs --numeric-owner -c vendor -C system --exclude='./vendor' .
) | zstd -T0 -19 -o "$temporary_output"
mv -- "$temporary_output" "$output"

echo "$output"
