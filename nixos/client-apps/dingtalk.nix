# 通用客户端应用：钉钉官方 Linux deb，取 NUR 的 so1ve 打包（仅 x86_64-linux）。
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
