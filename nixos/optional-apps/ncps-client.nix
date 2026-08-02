{ LT, lib, ... }:
{
  nix.settings.substituters = lib.mkForce [
    LT.nix.attic.url
    "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.Ncps}"
  ];
}
