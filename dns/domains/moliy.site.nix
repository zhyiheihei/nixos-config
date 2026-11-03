{
  config,
  lib,
  LT,
  ...
}:
let
  # 家宽入口沿用现有 DDNS 记录，避免改动设备侧更新脚本
  homeDdnsTarget = "home-ddns.zhyi.xin.";

  homeServices = [
    "asf"
    "books"
    "dav"
    "immich"
    "jellyfin"
    "mc"
    "mcsm"
    "mcsm-daemon"
    "memos"
    "openlist"
    "palworld"
    "qnap"
    "vaults3"
    "wallos"
  ];
in
{
  domains = [
    rec {
      domain = "moliy.site";
      registrar = "none";
      providers = [ "gcore" ];
      records = lib.flatten [
        config.common.hostRecs.CAA

        {
          recordType = "A";
          name = "@";
          address = LT.hosts.greencloud.public.IPv4;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "www";
          target = "@";
          ttl = "5m";
        }

        {
          recordType = "IGNORE";
          name = "home-ddns";
          type = "A,AAAA";
        }

        (map (name: {
          recordType = "CNAME";
          inherit name;
          target = homeDdnsTarget;
          ttl = "2m";
        }) homeServices)
      ];
    }
  ];
}
