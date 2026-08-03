#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [output.mp4]" >&2
  exit 2
fi

output=${1:-opi03-h264-test.mp4}

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to generate the deterministic H.264 sample" >&2
  exit 1
fi

# Encoding happens once on the x86 build host.  Runtime acceptance still forces
# Android to decode this ordinary H.264 High-profile stream through a hardware
# MediaCodec and separately proves Cedar/VE interrupt activity on opi03.
ffmpeg \
  -hide_banner \
  -loglevel error \
  -y \
  -f lavfi \
  -i 'testsrc2=size=1280x720:rate=30' \
  -t 6 \
  -an \
  -c:v libx264 \
  -preset veryfast \
  -profile:v high \
  -level:v 4.0 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "$output"

echo "$output"
