{ LT, lib, ... }:
{
  nix.settings.substituters = lib.mkForce [ "http://192.168.0.66:${LT.portStr.Ncps}" ];
}
