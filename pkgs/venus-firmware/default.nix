{
  fetchurl,
  runCommand,
  zstd,
}:
let
  # venus（小米 11 / SM8350）的 vendor 固件：ath11k WCN6851 hw1.1、Adreno 660、CS35L41 等。
  # 上游 linux-firmware 只有 WCN6851 hw2.0/2.1，hw1.1 必须用这份；内容与 venus 仓的 nixos/firmware 一致。
  firmwareTarball = fetchurl {
    url = "https://github.com/zhyiheihei/venus-mainline/releases/download/kernel-b08a5eb2/venus-firmware.tar.zst";
    hash = "sha256-eLBwvjIoHi9ZMhfADBpxmW3wc7uuO2nlBi3X5HbPhT8=";
  };
in
runCommand "venus-firmware" { nativeBuildInputs = [ zstd ]; } ''
  mkdir -p $out
  tar -xaf ${firmwareTarball} -C $out --strip-components=1
''
