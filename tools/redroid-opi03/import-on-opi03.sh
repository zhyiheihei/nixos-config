#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 opi03-redroid-android12-h618-rootfs.tar.zst" >&2
  exit 2
fi
if [[ $(id -u) -ne 0 ]]; then
  echo "run this script as root on opi03" >&2
  exit 1
fi

rootfs=$1
image=localhost/opi03-redroid:android12-h618
state=/nix/persistent/var/lib/redroid-opi03

test -f "$rootfs"
mkdir -p "$state/data"
chmod 0700 "$state" "$state/data"

zstd -dc -- "$rootfs" \
  | podman import \
      --change 'ENTRYPOINT ["/init","androidboot.hardware=redroid"]' \
      - "$image"

podman image exists "$image"
touch "$state/.image-ready"
systemctl restart podman-redroid.service
systemctl --no-pager --full status podman-redroid.service
