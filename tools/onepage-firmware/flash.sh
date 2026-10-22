#!/usr/bin/env bash
# OnePage 刷机：先读 flash 厂家（Winbond ef 可快刷；Puya 85 必须 --no-stub），再写 0x10000。
set -euo pipefail
BIN=${1:?firmware.bin}
PORT=${2:-/dev/ttyACM0}
ESPTOOL=(nix shell nixpkgs#esptool -c esptool --chip esp32c61 -p "$PORT")

VENDOR=$("${ESPTOOL[@]}" flash-id 2>/dev/null | sed -n 's/^Manufacturer: //p')
echo "flash manufacturer: ${VENDOR:-unknown}"
if [ "$VENDOR" = "85" ]; then
  "${ESPTOOL[@]}" --no-stub -b 115200 write-flash --flash-mode dio --flash-freq 80m --flash-size 16MB 0x10000 "$BIN"
else
  "${ESPTOOL[@]}" -b 921600 write-flash --flash-mode dio --flash-freq 80m --flash-size 16MB 0x10000 "$BIN"
fi
