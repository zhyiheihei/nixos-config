#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 /path/to/h618-android12-bsp" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bsp_root=$(cd -- "$1" && pwd)

# shellcheck source=source-lock.env
source "$script_dir/source-lock.env"

# Accept either the board-specific Orange Pi archive after every split part was
# checked against its official manifest, or the pinned BPI same-SoC reference
# repository.  Arbitrary Android trees are deliberately rejected: proprietary
# Mali/Cedar userspace has to match the audited H618 BSP generation.
bsp_monorepo=false
bsp_archive=false
bsp_origin=
official_marker="$bsp_root/.orangepi-official-source-manifest-sha256"
if [[ -f "$official_marker" ]]; then
  official_manifest_sha256=$(<"$official_marker")
  if [[ "$official_manifest_sha256" != "$ORANGEPI_ANDROID_SOURCE_MANIFEST_SHA256" ]]; then
    echo "Orange Pi source marker has unexpected manifest digest: $official_manifest_sha256" >&2
    exit 1
  fi
  bsp_archive=true
  bsp_origin="Orange Pi Zero 3 official Android 12 archive"
fi

if git -C "$bsp_root" rev-parse --show-toplevel >/dev/null 2>&1; then
  bsp_git_root=$(git -C "$bsp_root" rev-parse --show-toplevel)
  if [[ "$bsp_git_root" == "$bsp_root" ]]; then
    bsp_head=$(git -C "$bsp_root" rev-parse HEAD)
    if [[ "$bsp_head" != "$BPI_H618_BSP_COMMIT" ]]; then
      echo "H618 BSP is at $bsp_head, expected $BPI_H618_BSP_COMMIT" >&2
      exit 1
    fi
    bsp_monorepo=true
    bsp_origin="BPI official H618 Android 12 commit $BPI_H618_BSP_COMMIT"
  fi
fi

if [[ "$bsp_archive" != true && "$bsp_monorepo" != true ]]; then
  echo "unverified H618 Android tree: $bsp_root" >&2
  echo "expected the Orange Pi manifest marker or BPI commit $BPI_H618_BSP_COMMIT" >&2
  exit 1
fi

for required in \
  build/make \
  frameworks/base \
  frameworks/av \
  frameworks/av/media/libcedarc/libcdclist.mk \
  frameworks/av/media/libcedarc/conf/cedarc.conf \
  hardware/aw/gpu \
  hardware/aw/gpu/mali-bifrost/mali-g31/arm64/lib/libGLES_mali.so \
  hardware/aw/gpu/mali-bifrost/mali-g31/arm64/lib64/libGLES_mali.so \
  hardware/aw/libcodec2 \
  hardware/aw/libcodec2/services/Android.bp \
  device/softwinner/apollo \
  device/softwinner/apollo/common/media/codec/media_codecs_allwinner_video.xml \
  vendor/aw
do
  if [[ ! -e "$bsp_root/$required" ]]; then
    echo "not an H618 Android 12 BSP tree; missing: $required" >&2
    exit 1
  fi
done

checkout_component() {
  local path=$1
  local url=$2
  local commit=$3
  local destination="$bsp_root/$path"

  if [[ -e "$destination/.git" ]]; then
    local current
    current=$(git -C "$destination" rev-parse HEAD)
    if [[ "$current" != "$commit" ]]; then
      if [[ -n $(git -C "$destination" status --porcelain) ]]; then
        echo "$path is dirty at $current; refusing to replace it with $commit" >&2
        exit 1
      fi
      git -C "$destination" fetch --depth 1 origin "$commit"
      git -C "$destination" checkout --detach "$commit"
    fi
    return
  fi

  if [[ -e "$destination" ]]; then
    echo "$destination exists but is not a Git checkout; move it aside first" >&2
    exit 1
  fi

  mkdir -p "$(dirname -- "$destination")"
  git clone --filter=blob:none --no-checkout "$url" "$destination"
  git -C "$destination" fetch --depth 1 origin "$commit"
  git -C "$destination" checkout --detach "$commit"
}

checkout_component device/redroid https://github.com/remote-android/device_redroid.git "$DEVICE_REDROID_COMMIT"
checkout_component vendor/redroid https://github.com/remote-android/vendor_redroid.git "$VENDOR_REDROID_COMMIT"
checkout_component device/redroid-prebuilts https://github.com/remote-android/device_redroid-prebuilts.git "$DEVICE_REDROID_PREBUILTS_COMMIT"
checkout_component hardware/redroid/c2 https://github.com/remote-android/redroid-c2.git "$REDROID_C2_COMMIT"
checkout_component hardware/redroid/omx https://github.com/remote-android/redroid-omx.git "$REDROID_OMX_COMMIT"

patches_root="$bsp_root/.redroid-opi03/redroid-patches"
if [[ ! -e "$patches_root/.git" ]]; then
  mkdir -p "$(dirname -- "$patches_root")"
  git clone --filter=blob:none --no-checkout \
    https://github.com/remote-android/redroid-patches.git "$patches_root"
  git -C "$patches_root" fetch --depth 1 origin "$REDROID_PATCHES_COMMIT"
  git -C "$patches_root" checkout --detach "$REDROID_PATCHES_COMMIT"
elif [[ $(git -C "$patches_root" rev-parse HEAD) != "$REDROID_PATCHES_COMMIT" ]]; then
  echo "$patches_root is not at the locked commit" >&2
  exit 1
fi

apply_one_patch() {
  local project=$1
  local relative_project=$2
  local patch_file=$3

  if [[ ! -e "$project/.git" ]]; then
    # BPI publishes Android as one repository, while Orange Pi publishes a
    # verified tar archive without nested project history.  `git apply` does
    # not require a worktree repository for this operation.  The upstream
    # reDroid patches are rooted at individual AOSP projects, so prepend that
    # project path.  Reverse checks keep both layouts idempotent.
    if git -C "$bsp_root" apply \
      --directory="$relative_project" --reverse --check "$patch_file" \
      >/dev/null 2>&1
    then
      echo "already applied: ${patch_file#"$patches_root/"}"
      return
    fi
    if ! git -C "$bsp_root" apply \
      --directory="$relative_project" --check "$patch_file"
    then
      echo "patch does not match the locked H618 BSP: $patch_file" >&2
      exit 1
    fi
    git -C "$bsp_root" apply --directory="$relative_project" "$patch_file"
    return
  fi

  if git -C "$project" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "already applied: ${patch_file#"$patches_root/"}"
    return
  fi
  if ! git -C "$project" apply --check "$patch_file"; then
    echo "patch does not match the H618 BSP: $patch_file" >&2
    exit 1
  fi
  if ! git -C "$project" \
    -c user.name=redroid-opi03 \
    -c user.email=redroid-opi03@localhost \
    am --3way "$patch_file"
  then
    git -C "$project" am --abort || true
    echo "failed to apply reDroid patch cleanly: $patch_file" >&2
    exit 1
  fi
}

patch_set="$patches_root/$REDROID_PATCH_TAG"
while IFS= read -r patch_directory; do
  relative_project=${patch_directory#"$patch_set/"}
  project="$bsp_root/$relative_project"
  while IFS= read -r patch_file; do
    apply_one_patch "$project" "$relative_project" "$patch_file"
  done < <(find "$patch_directory" -maxdepth 1 -type f -name '*.patch' -print | sort)
done < <(find "$patch_set" -type f -name '*.patch' -exec dirname {} \; | sort -u)

vendor_patch="$script_dir/patches/vendor-redroid-opi03.patch"
if git -C "$bsp_root/vendor/redroid" apply --reverse --check "$vendor_patch" >/dev/null 2>&1; then
  echo "already applied: vendor-redroid-opi03.patch"
else
  git -C "$bsp_root/vendor/redroid" apply --check "$vendor_patch"
  git -C "$bsp_root/vendor/redroid" apply "$vendor_patch"
fi

install -Dm0644 \
  "$script_dir/overlay/device/redroid/redroid_opi03.mk" \
  "$bsp_root/device/redroid/redroid_opi03.mk"
install -Dm0644 \
  "$script_dir/overlay/device/redroid/redroid_opi03/BoardConfig.mk" \
  "$bsp_root/device/redroid/redroid_opi03/BoardConfig.mk"
install -Dm0644 \
  "$script_dir/overlay/device/redroid/redroid_opi03/device.mk" \
  "$bsp_root/device/redroid/redroid_opi03/device.mk"
install -Dm0644 \
  "$script_dir/overlay/vendor/redroid_opi03/device.mk" \
  "$bsp_root/vendor/redroid_opi03/device.mk"
install -Dm0644 \
  "$script_dir/overlay/vendor/redroid_opi03/media_codecs.xml" \
  "$bsp_root/vendor/redroid_opi03/media_codecs.xml"
install -Dm0644 \
  "$script_dir/overlay/vendor/redroid_opi03/redroid.opi03.rc" \
  "$bsp_root/vendor/redroid_opi03/redroid.opi03.rc"

# The H618 Android 12 BSP ships its CedarX video stack as 32-bit-only and
# includes an OMX layer that collides with reDroid's Codec2 product.  Apply
# the audited, build-proven fixes: expose the 64-bit CedarX prebuilts, drop
# the BSP OMX stack (reDroid uses Codec2, not OMX), make reDroid's OMX
# prebuilt conditional on REDROID_DISABLE_OMX, and default the cedarx/cedarc
# Go config to board=apollo, and the c2codec_config.go GPU_PUBLIC_INCLUDE
# default.  The BSP-file patches are cedarx-external-multilib,
# cedarc-library-arm64, cedarc-top-no-openmax, cedarc-config-board-default,
# cedarx-config-board-default and c2codec-config-gpu-default; the two
# redroid-* ones target reDroid component checkouts.  Each is written against
# the pristine file so application is idempotent across the Orange Pi and BPI
# baselines.
apply_bsp_patch() {
  local patch_file=$1

  if git -C "$bsp_root" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "already applied: ${patch_file##*/}"
  elif git -C "$bsp_root" apply --check "$patch_file" >/dev/null 2>&1; then
    git -C "$bsp_root" apply "$patch_file"
    echo "applied: ${patch_file##*/}"
  else
    echo "BSP patch does not match the locked source: $patch_file" >&2
    exit 1
  fi
}

apply_bsp_patch "$script_dir/patches/cedarx-external-multilib.patch"
apply_bsp_patch "$script_dir/patches/cedarc-library-arm64.patch"
apply_bsp_patch "$script_dir/patches/cedarc-top-no-openmax.patch"
apply_bsp_patch "$script_dir/patches/cedarc-config-board-default.patch"
apply_bsp_patch "$script_dir/patches/cedarx-config-board-default.patch"
apply_bsp_patch "$script_dir/patches/c2codec-config-gpu-default.patch"
apply_bsp_patch "$script_dir/patches/stagefright-foundation-abi-check.patch"
apply_bsp_patch "$script_dir/patches/redroid-prebuilts-omx-conditional.patch"
apply_bsp_patch "$script_dir/patches/redroid-omx-conditional.patch"

# soong scans every Android.bp under the source root; a disabled directory is
# still scanned.  Move the BSP OMX tree out of the source root entirely.  The
# backup path is a fixed sibling of the source root, so guard against
# accidentally deleting an unrelated directory: only remove a previous backup
# that carries our marker, and only move when openmax is really inside the
# source root.
openmax_dir="$bsp_root/frameworks/av/media/libcedarc/openmax"
backup_dir="$bsp_root/../openmax-bsp-backup"
if [[ -e "$openmax_dir" ]]; then
  if [[ ! -d "$openmax_dir" ]]; then
    echo "openmax exists but is not a directory: $openmax_dir" >&2
    exit 1
  fi
  if [[ -e "$backup_dir" && ! -f "$backup_dir/.opi03-bsp-backup" ]]; then
    echo "refusing to replace non-script backup: $backup_dir" >&2
    exit 1
  fi
  rm -rf "$backup_dir"
  mv "$openmax_dir" "$backup_dir"
  touch "$backup_dir/.opi03-bsp-backup"
  echo "moved BSP OMX stack out of source root"
fi

android_products="$bsp_root/device/redroid/AndroidProducts.mk"
if ! grep -qF '$(LOCAL_DIR)/redroid_opi03.mk' "$android_products"; then
  printf '\nPRODUCT_MAKEFILES += $(LOCAL_DIR)/redroid_opi03.mk\n' >> "$android_products"
fi
if ! grep -qF 'redroid_opi03-userdebug' "$android_products"; then
  printf 'COMMON_LUNCH_CHOICES += redroid_opi03-userdebug\n' >> "$android_products"
fi

echo
echo "opi03 source overlay prepared successfully from: $bsp_origin"
echo "next: source build/envsetup.sh && lunch redroid_opi03-userdebug && m -j8 systemimage vendorimage"
