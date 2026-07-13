{ ... }:
{
  domains = [
    {
      domain = "moliy.site";
      registrar = "none";
      providers = [ "gcore" ];
      enableWildcard = false;
      records = [
        {
          recordType = "NO_PURGE";
          name = "@";
        }
        {
          recordType = "CNAME";
          name = "autoconfig";
          target = "home-ddns.zhyi.cc.";
          ttl = "10m";
        }
      ];
    }
  ];
}
