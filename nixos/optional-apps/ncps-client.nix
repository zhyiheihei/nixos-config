{ LT, lib, ... }:
{
  services.nix-cache-proxy.enable = lib.mkForce false;
  nix.settings.substituters = lib.mkForce [
    LT.nix.attic.url
    "http://${LT.hosts."ml-home-vm".interconnect.IPv4}:${LT.portStr.Ncps}"
  ];
}
