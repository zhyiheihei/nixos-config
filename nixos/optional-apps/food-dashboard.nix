# 接入壳：EPD 家庭食品存储看板。包与 NixOS 模块主体在 zhyi-packages
# （nixosModules.food-dashboard + epd-food-server 包），主机按需设
# lantian.food-dashboard.enable；API/WebUI 均为内网私有服务，不开公网入口。
{
  inputs,
  ...
}:
{
  imports = [ inputs.zhyi-packages.nixosModules.food-dashboard ];
}
