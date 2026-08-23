{
  LT,
  lib,
  ...
}:
{
  # Private Attic first, then the author's public NUR cache, then NCPS fallback.
  # NCPS 地址跟随 hosts/opi5p/host.nix 的 interconnect.IPv4；
  # 上游硬编码的 192.168.0.4 是作者自己局域网的地址，在本机群不存在。
  nix.settings.substituters = lib.mkForce [
    LT.nix.attic.url
    "https://attic.xuyh0120.win/lantian"
    "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.Ncps}"
  ];
}
