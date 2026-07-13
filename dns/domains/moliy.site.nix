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
          recordType = "CNAME";
          name = "autoconfig";
          target = "home-ddns.zhyi.cc.";
          ttl = "10m";
        }
      ];
    }
  ];
}
