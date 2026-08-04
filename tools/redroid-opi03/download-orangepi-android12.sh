#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/output-directory" >&2
  exit 2
fi

output_dir=$1
parts_dir="$output_dir/parts"
extract_dir="$output_dir/extracted"
gdown_bin=${GDOWN_BIN:-gdown}
gdown_proxy=${GDOWN_PROXY:-}
gdown_max_attempts=${GDOWN_MAX_ATTEMPTS:-48}
gdown_retry_seconds=${GDOWN_RETRY_SECONDS:-1800}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=source-lock.env
source "$script_dir/source-lock.env"

manifest=H618-Android12-Src.tar.gz.md5sum
manifest_id=13ejYKxuEnSIIpvxWWk8PAKizo9ZheniG
manifest_sha256=$ORANGEPI_ANDROID_SOURCE_MANIFEST_SHA256

suffixes=(aa ab ac ad ae af ag ah ai aj ak al am an ao ap aq ar)
ids=(
  1Q4gLRfyE9srp5Cp1nAvrG_tnlnx9jKVU
  1duS5BvHOsDGe77RL028d0CL5pp6skleZ
  1LWHtknCmsJ3Q7GUh2h7nQA5oAX8qtUch
  12dfaJm_S9rZzPl7eTPZDeNTb6c9rOYos
  1wn7klkktJn7UwU5jnUkzGXD_5hYWQs5a
  1KDFBK8beqwUtMVJwDqqSAZOrJNR86njl
  1-mKmYDNrFQZDPqgymIzoqMPdw2F-QDvs
  1QxBofP5DCEeaz3__pXT0SgKwAtaygncn
  1peWhHeWkPv_kVtcKG6y8zcv6gqypyEvV
  1vm7MSCdxZr4FE1qHDBC4Y56a92sVcB51
  1lbdCDCFT08x18-0t4XLN48GhRaHm7goG
  1d_-kxsewcUGmgESf5ViDkX8-hgGF_xUX
  1CPrMl_Skrpl1u4YkiGZpdxBybN47w_mI
  11oROiMEHlpbeOgREOI7Bg5qAb40zZutn
  1gwUeDilv0hopjdc1B1cfBIhlQBX-8QGn
  1Wu1dqi_LBeGAGnWOnzvBRnjEsdrwNIWS
  1V2JyUdaF-ir3IqiZ6ZexFG108OkGnj2I
  1Iwn6sV1vdCfANQofqLpIS-Ai6RBGqiyY
)

mkdir -p "$parts_dir"

gdown_args=(--quiet --continue)
if [[ -n "$gdown_proxy" ]]; then
  gdown_args+=(--proxy "$gdown_proxy")
fi

download() {
  local id=$1
  local destination=$2
  local attempt

  for ((attempt = 1; attempt <= gdown_max_attempts; attempt++)); do
    if "$gdown_bin" "${gdown_args[@]}" -O "$destination" "$id"; then
      return 0
    fi

    if ((attempt == gdown_max_attempts)); then
      cat >&2 <<EOF
Google Drive did not provide $destination after $attempt attempt(s).
The same source is published on Orange Pi's official Chinese support page:
  $ORANGEPI_ANDROID_SOURCE_BAIDU_URL
  extraction code: $ORANGEPI_ANDROID_SOURCE_BAIDU_CODE
Download the split archives into $parts_dir and rerun this script; every file
will still be checked against the pinned official manifest before extraction.
EOF
      return 1
    fi

    echo "download failed; retrying in $gdown_retry_seconds seconds ($attempt/$gdown_max_attempts)" >&2
    sleep "$gdown_retry_seconds"
  done
}

# Download one part and verify its MD5 against the official manifest.  gdown
# 6.1.0 performs no integrity check (upstream issue #477): a "successful"
# download can still be corrupt (we hit this with the ae part).  A corrupt file
# is removed and re-downloaded, up to gdown_max_attempts.
download_part() {
  local id=$1
  local part=$2
  local expected=$3
  local attempt

  for ((attempt = 1; attempt <= gdown_max_attempts; attempt++)); do
    if [[ -f "$parts_dir/$part" ]] \
      && printf '%s  %s\n' "$expected" "$parts_dir/$part" \
        | md5sum --check --strict --status
    then
      echo "verified existing $part"
      return 0
    fi

    # stale or corrupt file (e.g. from an interrupted/`--continue` run) would
    # otherwise be kept and fail md5sum forever
    if [[ -f "$parts_dir/$part" ]]; then
      echo "$part failed MD5 check; removing and re-downloading" >&2
      rm -f "$parts_dir/$part"
    fi

    if download "$id" "$parts_dir/$part"; then
      if printf '%s  %s\n' "$expected" "$parts_dir/$part" \
        | md5sum --check --strict --status
      then
        echo "downloaded and verified $part ($((index + 1))/${#suffixes[@]})"
        return 0
      fi
      echo "$part downloaded but MD5 mismatch; will retry" >&2
      rm -f "$parts_dir/$part"
    fi

    if ((attempt == gdown_max_attempts)); then
      echo "giving up on $part after $attempt attempt(s)" >&2
      return 1
    fi

    echo "retrying $part in $gdown_retry_seconds seconds ($attempt/$gdown_max_attempts)" >&2
    sleep "$gdown_retry_seconds"
  done
}

if [[ -f "$parts_dir/$manifest" ]] \
  && printf '%s  %s\n' "$manifest_sha256" "$parts_dir/$manifest" \
    | sha256sum --check --strict --status
then
  echo "verified existing Orange Pi checksum manifest"
else
  echo "downloading the Orange Pi checksum manifest"
  download "$manifest_id" "$parts_dir/$manifest"
  printf '%s  %s\n' "$manifest_sha256" "$parts_dir/$manifest" \
    | sha256sum --check --strict
fi

for index in "${!suffixes[@]}"; do
  suffix=${suffixes[$index]}
  part="H618-Android12-Src.tar.gz$suffix"
  expected=$(awk -v part="$part" '$2 == part { print $1 }' "$parts_dir/$manifest")
  if [[ -z "$expected" ]]; then
    echo "official manifest does not contain $part" >&2
    exit 1
  fi

  if [[ -f "$parts_dir/$part" ]] \
    && printf '%s  %s\n' "$expected" "$parts_dir/$part" \
      | md5sum --check --strict --status
  then
    echo "verified existing $part"
    continue
  fi

  echo "downloading $part ($((index + 1))/${#suffixes[@]})"
  if ! download_part "${ids[$index]}" "$part" "$expected"; then
    echo "failed to obtain a verified $part; rerun after fixing the download source" >&2
    exit 1
  fi
done

echo "verifying all official source parts"
(
  cd "$parts_dir"
  md5sum --check --strict "$manifest"
)

if [[ -e "$extract_dir/.complete" ]]; then
  echo "official source is already extracted: $extract_dir"
  exit 0
fi
if [[ -e "$extract_dir" ]]; then
  echo "$extract_dir exists without .complete; move it aside before retrying" >&2
  exit 1
fi

temporary_extract=$(mktemp -d "$output_dir/extracted.partial.XXXXXXXX")
echo "streaming the verified split archive into $temporary_extract"
part_paths=()
for suffix in "${suffixes[@]}"; do
  part_paths+=("$parts_dir/H618-Android12-Src.tar.gz$suffix")
done
cat -- "${part_paths[@]}" | tar -xzf - -C "$temporary_extract"

build_make=$(find "$temporary_extract" -type d -path '*/build/make' -print -quit)
if [[ -z "$build_make" ]]; then
  echo "extracted archive is missing build/make: $temporary_extract" >&2
  exit 1
fi

source_root=$(dirname -- "$(dirname -- "$build_make")")
source_root_relative=${source_root#"$temporary_extract"/}
for required in \
  frameworks/base \
  frameworks/av \
  hardware/aw/gpu \
  hardware/aw/libcodec2 \
  device/softwinner/apollo \
  vendor/aw
do
  if [[ ! -e "$source_root/$required" ]]; then
    echo "official archive is missing $required: $source_root" >&2
    exit 1
  fi
done

printf '%s\n' "$manifest_sha256" \
  >"$source_root/.orangepi-official-source-manifest-sha256"
cat >"$source_root/.orangepi-official-source-origin" <<EOF
Google Drive folder: https://drive.google.com/drive/folders/$ORANGEPI_ANDROID_SOURCE_GOOGLE_FOLDER_ID
Baidu share: $ORANGEPI_ANDROID_SOURCE_BAIDU_URL
Baidu extraction code: $ORANGEPI_ANDROID_SOURCE_BAIDU_CODE
Checksum manifest SHA256: $manifest_sha256
EOF
printf '%s\n' "$manifest_sha256" >"$temporary_extract/.official-manifest-sha256"
touch "$temporary_extract/.complete"
mv -- "$temporary_extract" "$extract_dir"

echo "verified Orange Pi H618 Android 12 source: $extract_dir/$source_root_relative"
