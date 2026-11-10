# 接入壳：包与模块主体在 zhyi-packages。通用客户端应用，client 角色默认启用；
# 包仅支持 x86_64-linux，模块内按平台过滤。
{
  inputs,
  ...
}:
{
  imports = [ inputs.zhyi-packages.nixosModules.nextai-translator ];

  lantian.nextai-translator.enable = true;
}
