{
  LT,
  lib,
  ...
}:
let
  ncpsUrl = "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.Ncps}";
in
{
  # Author's Attic first (has most upstream packages), then private Attic,
  # then NCPS fallback.
  # NCPS 地址跟随 hosts/opi5p/host.nix 的 interconnect.IPv4；
  # 上游硬编码的 192.168.0.4 是作者自己局域网的地址，在本机群不存在。
  nix.settings.substituters = lib.mkForce [
    "https://attic.xuyh0120.win/lantian"
    LT.nix.attic.url
    ncpsUrl
  ];

  # http 明文 substituter 必须同时出现在 trusted-substituters 里，否则 nix
  # 出于安全策略会把它标记为 disabled（报 "substituter ... is disabled"）。
  # NCPS 透传 cache.nixos.org-1 签名，官方公钥已在 trusted-public-keys 里。
  nix.settings.trusted-substituters = lib.mkForce (
    LT.constants.nix.substituters ++ [ ncpsUrl ]
  );
}
