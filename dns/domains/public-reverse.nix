{ config, ... }:
{
  domains = [
    (config.common.reverse6 {
      prefix = "2001:470:8a6d::/48";
      target = "cnvm.zhyi.cc.";
    })
    (config.common.reverse6 {
      prefix = "2001:470:1f07:54d::/64";
      target = "cnvm.zhyi.cc.";
    })

    (config.common.reverse6 {
      prefix = "2001:470:8c19::/48";
      target = "colocrossing.zhyi.cc.";
    })
    (config.common.reverse6 {
      prefix = "2001:470:1f07:6fe::/64";
      target = "colocrossing.zhyi.cc.";
    })

    (config.common.reverse6 {
      prefix = "2001:470:e997::/48";
      target = "ml-home-vm.zhyi.cc.";
    })
    (config.common.reverse6 {
      prefix = "2001:470:b:3af::/64";
      target = "ml-home-vm.zhyi.cc.";
    })

    (config.common.reverse6 {
      prefix = "2605:6400:cac6::/48";
      target = "jpvm.zhyi.cc.";
    })

    (config.common.reverse6 {
      prefix = "2a03:94e0:27ca::/48";
      target = "jpvm.zhyi.cc.";
    })
  ];
}
