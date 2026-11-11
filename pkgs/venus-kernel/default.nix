{
  callPackage,
  fetchurl,
  runCommand,
  zstd,
  venusMainline,
  ...
}@args:
let
  # 设备实际在跑的内核工件（v0.1.0 基线：Image b08a5eb2 / DTB 7dfa5389 / 646 个模块 / config）。
  # 来源是设备原版 boot_b 整份 dump，见 venus-mainline 的 kernel-b08a5eb2 release。
  kernelTarball = fetchurl {
    url = "https://github.com/zhyiheihei/venus-mainline/releases/download/kernel-b08a5eb2/venus-kernel-artifacts.tar.zst";
    hash = "sha256-DRRT/PVsPxEVFmLJbbAwOnSj5fDECKWEumwhnAEzMHM=";
  };
  artifacts = runCommand "venus-kernel-artifacts" { nativeBuildInputs = [ zstd ]; } ''
    mkdir -p $out
    tar -xaf ${kernelTarball} -C $out
  '';
  # fleet 侧会通过 .override { features = ...; } 传内核参数，原样透传给内核包
  extra = builtins.removeAttrs args [
    "callPackage"
    "fetchurl"
    "runCommand"
    "zstd"
    "venusMainline"
  ];
in
callPackage (venusMainline + "/nixos/kernel-prebuilt.nix") (extra // { inherit artifacts; })
