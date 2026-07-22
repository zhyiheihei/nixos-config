{ config, ... }:
{
  domains = [
    (config.common.reverse6 {
      prefix = "2a11:8083:11:191b::/64";
      target = "sgvm.zhyi.cc.";
    })
  ];
}
