{
  pkgs,
  lib,
  ...
}:
let
  package = pkgs.nur.repos.so1ve.dingtalk;
in
{
  environment.systemPackages = lib.optional (lib.meta.availableOn pkgs.stdenv.hostPlatform package) package;
}
