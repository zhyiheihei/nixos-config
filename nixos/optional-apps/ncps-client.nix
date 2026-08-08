{ LT, lib, ... }:
{
  # Private Attic first, then the author's public NUR cache, then NCPS fallback.
  nix.settings.substituters = lib.mkForce [
    LT.nix.attic.url
    "https://attic.xuyh0120.win/lantian"
    "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.Ncps}"
  ];
}
