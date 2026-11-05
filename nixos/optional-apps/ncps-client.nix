{ LT, lib, ... }:
{
  nix.settings.substituters = lib.mkBefore [ "http://192.168.0.56:${LT.portStr.Ncps}" ];
}
