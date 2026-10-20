# 接入壳：包与模块主体在 zhyi-packages，主机按需设 lantian.qingjian.enable。
{
  inputs,
  ...
}:
{
  imports = [ inputs.zhyi-packages.nixosModules.qingjian ];
}
