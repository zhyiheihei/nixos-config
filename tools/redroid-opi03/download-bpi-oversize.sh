#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 OUTPUT_DIRECTORY" >&2
  echo "set GDOWN_BIN and GDOWN_PROXY when they are not discoverable" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage

output_dir=$1
gdown_bin=${GDOWN_BIN:-gdown}
gdown_proxy=${GDOWN_PROXY:-${HTTPS_PROXY:-${https_proxy:-}}}

part_00_id=1PP4u83z0D9wtr2uFvje1dbdETW6_PaG6
part_01_id=1cbybcEHHCqwbOlUjunV8hG7JnLtWz6-f
part_00_md5=f3c0d755eda3d0dd9303a9c01c1e44ad
part_01_md5=009e94c19c9b4a5943c7868694f77f19
archive_md5=fb980a48604dac94dd15fb7422c555b8

install -d "$output_dir"

gdown_args=(--continue)
if [[ -n "$gdown_proxy" ]]; then
  gdown_args+=(--proxy "$gdown_proxy")
fi

download_part() {
  local id=$1
  local destination=$2
  "$gdown_bin" "${gdown_args[@]}" \
    --output "$destination" \
    "https://drive.google.com/uc?id=$id"
}

download_part "$part_00_id" "$output_dir/github_oversize_files_00"
download_part "$part_01_id" "$output_dir/github_oversize_files_01"

(
  cd "$output_dir"
  printf '%s  %s\n' "$part_00_md5" github_oversize_files_00 | md5sum --check --strict
  printf '%s  %s\n' "$part_01_md5" github_oversize_files_01 | md5sum --check --strict

  # BPI publishes the archive as two byte-for-byte split parts. Rebuild it in
  # the official order, then verify the checksum from the folder's readme.
  cat github_oversize_files_00 github_oversize_files_01 \
    >github_oversize_files.tar.gz
  printf '%s  %s\n' "$archive_md5" github_oversize_files.tar.gz \
    | md5sum --check --strict

  install -d extracted
  tar -xzf github_oversize_files.tar.gz -C extracted
)

test -d "$output_dir/extracted/github_oversize_files"
echo "verified oversize payload: $output_dir/extracted/github_oversize_files"
echo "merge this directory into the locked BPI Android source root before prepare-source.sh"
