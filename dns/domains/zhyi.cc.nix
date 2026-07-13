{ ... }:
{
  domains = [
    rec {
      domain = "zhyi.cc";
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
          name = "sub";
          target = "tw";
          ttl = "10m";
        }
        {
          recordType = "A";
          name = "ml-home-vm";
          address = "192.168.2.135";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "*.ml-home-vm";
          target = "ml-home-vm.zhyi.cc.";
          ttl = "10m";
        }
      ];
    }
  ];
}
