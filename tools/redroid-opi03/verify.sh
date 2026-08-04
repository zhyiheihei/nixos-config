#!/usr/bin/env bash
set -euo pipefail

# Stage 1 (default) verifies the Mali GPU path only.  Pass --stage2-codec2 to
# also require the Allwinner Codec2 hardware decode stack (deferred until the
# vendor libcedarc 64-bit blobs are Android bionic, see docs).
stage2_codec2=false
args=()
for a in "$@"; do
  case "$a" in
    --stage2-codec2) stage2_codec2=true ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"
container=${1:-redroid}
mode=${2:-check}

cedar_interrupts() {
  awk '
    BEGIN { IGNORECASE = 1 }
    /cedar|video.?engine|sunxi.?ve|(^|[[:space:]])ve([[:space:]]|$)/ {
      for (i = 2; i <= NF && $i ~ /^[0-9]+$/; i++) {
        total += $i
      }
    }
    END { print total + 0 }
  ' /proc/interrupts
}

if [[ "$mode" == "watch-vpu" ]]; then
  echo "Start H.264/H.265 playback in Android now; Ctrl-C stops monitoring."
  while true; do
    date --iso-8601=seconds
    grep -iE 'cedar|(^|[^a-z])ve([^a-z]|$)' /proc/interrupts || true
    podman exec "$container" sh -c '
      for fd in /proc/[0-9]*/fd/*; do
        target=$(readlink "$fd" 2>/dev/null || true)
        case "$target" in
          *cedar_dev*) echo "$fd -> $target" ;;
        esac
      done
    ' || true
    sleep 1
  done
fi

if [[ "$mode" == "decode-test" ]]; then
  if [[ "$stage2_codec2" != true ]]; then
    echo "decode-test is a Stage 2 (Codec2/Cedar) gate; pass --stage2-codec2" >&2
    exit 2
  fi
  sample=${3:-}
  if [[ -z "$sample" || ! -f "$sample" ]]; then
    echo "usage: $0 $container decode-test /path/to/h264-or-h265-sample.mp4" >&2
    exit 2
  fi

  target=/data/local/tmp/opi03-hwdecode-sample.mp4
  podman exec "$container" logcat -c >/dev/null 2>&1 || true
  podman cp "$sample" "$container:$target" >/dev/null

  before=$(cedar_interrupts)
  set +e
  decode_output=$(podman exec "$container" \
    stagefright -r -S -q -m 240 "$target" 2>&1)
  decode_status=$?
  set -e
  after=$(cedar_interrupts)

  printf '%s\n' "$decode_output"
  codec_log=$(podman exec "$container" logcat -d -v brief 2>&1 \
    | grep -iE 'c2\.allwinner|AvcDecComponent|HevcDecComponent|Cedar|libVE|vdecoder' \
    || true)
  if [[ -n "$codec_log" ]]; then
    printf '%s\n' "$codec_log"
  fi

  failed=0
  if (( decode_status != 0 )); then
    echo "FAIL: stagefright exited with $decode_status" >&2
    failed=1
  elif ! grep -qE 'decoded a total of [1-9][0-9]* frame' <<< "$decode_output"; then
    echo "FAIL: stagefright did not report decoded video frames" >&2
    failed=1
  else
    echo "PASS: stagefright forced a hardware decoder and decoded frames"
  fi

  if (( after > before )); then
    echo "PASS: Cedar/VE interrupt count increased: $before -> $after"
  else
    echo "FAIL: Cedar/VE interrupt count did not increase: $before -> $after" >&2
    failed=1
  fi

  if [[ -n "$codec_log" ]]; then
    echo "PASS: Allwinner/Cedar decoder activity appeared in Android logcat"
  else
    echo "FAIL: no Allwinner/Cedar decoder activity appeared in Android logcat" >&2
    failed=1
  fi

  exit "$failed"
fi

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}
pass() {
  echo "PASS: $*"
}

for node in /dev/mali0 /dev/cedar_dev /dev/ion /dev/g2d; do
  if [[ -c "$node" ]]; then
    pass "$node exists"
  else
    fail "$node is missing"
  fi
done

if lsmod | grep -q '^mali_kbase '; then
  pass "mali_kbase is loaded"
else
  fail "mali_kbase is not loaded"
fi

if [[ $(podman inspect --format '{{.State.Running}}' "$container" 2>/dev/null || true) == true ]]; then
  pass "container $container is running"
else
  fail "container $container is not running"
fi

boot_completed=$(podman exec "$container" getprop sys.boot_completed 2>/dev/null || true)
if [[ "$boot_completed" == 1 ]]; then
  pass "Android boot completed"
else
  fail "Android boot is incomplete: ${boot_completed:-unset}"
fi

check_property() {
  local property=$1
  local expected=$2
  local value
  value=$(podman exec "$container" getprop "$property" 2>/dev/null || true)
  if [[ "$value" == "$expected" ]]; then
    pass "$property=$value"
  else
    fail "$property=${value:-unset}, expected $expected"
  fi
}

check_property ro.hardware.egl mali
check_property ro.hardware.gralloc apollo
check_property ro.hardware.vulkan apollo
check_property debug.stagefright.ccodec 4

surfaceflinger=$(podman exec "$container" dumpsys SurfaceFlinger 2>&1 || true)
renderer=$(grep -im1 -E 'GLES:|GL_RENDERER|Mali' <<< "$surfaceflinger" || true)
if [[ -z "$renderer" ]]; then
  fail "SurfaceFlinger did not report a renderer"
elif grep -qiE 'swiftshader|llvmpipe|angle|pastel' <<< "$renderer"; then
  fail "software renderer selected: $renderer"
else
  pass "hardware renderer: $renderer"
fi

if [[ "$stage2_codec2" == true ]]; then
  c2_processes=$(podman exec "$container" ps -A 2>&1 | grep -i 'media.aw.c2' || true)
  if [[ -n "$c2_processes" ]]; then
    pass "Allwinner Codec2 service is running"
  else
    fail "android.hardware.media.aw.c2 service is not running"
  fi

  c2_hal=$(podman exec "$container" lshal 2>&1 | grep -iE 'media\.c2|allwinner' || true)
  if [[ -n "$c2_hal" ]]; then
    pass "Allwinner Codec2 HAL is registered"
  else
    fail "Allwinner Codec2 HAL is not registered"
  fi

  codec_xml=$(podman exec "$container" sh -c \
    "grep -R 'c2.allwinner.avc.decoder' /vendor/etc/media_codecs*.xml" 2>/dev/null || true)
  if [[ -n "$codec_xml" ]]; then
    pass "c2.allwinner AVC decoder is advertised"
  else
    fail "c2.allwinner codec XML is absent"
  fi

  codec_list=$(podman exec "$container" stagefright -i 2>&1 || true)
  if grep -q 'c2.allwinner.avc.decoder' <<< "$codec_list" \
    && grep -q 'c2.allwinner.hevc.decoder' <<< "$codec_list"
  then
    pass "Android runtime codec list contains Allwinner AVC and HEVC decoders"
  else
    fail "Android runtime codec list does not expose both Allwinner AVC and HEVC decoders"
  fi
fi

if (( failures > 0 )); then
  echo "$failures acceptance check(s) failed" >&2
  exit 1
fi

echo "Static GPU/VPU gates passed. Run: opi03-redroid-check $container watch-vpu"
echo "Runtime gate: opi03-redroid-check $container decode-test /path/to/sample.mp4"
