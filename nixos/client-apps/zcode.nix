# ZCode（Z.ai 官方 AI 编码桌面应用，GLM harness）。
# 包与模块主体都在 zhyi-packages（nixos-modules/zcode.nix）；本文件只是
# client 角色的接入壳：导入上游模块，主机按需设 lantian.zcode.enable。
{
  inputs,
  ...
}:
{
  imports = [ inputs.zhyi-packages.nixosModules.zcode ];
}
