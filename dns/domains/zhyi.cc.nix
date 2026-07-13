{ ... }:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";
  twvmTarget = "tw.zhyi.cc.";
in
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
          target = twvmTarget;
          ttl = "10m";
        }
        {
          recordType = "IGNORE";
          name = "home-ddns";
          type = "A,AAAA";
        }
        {
          recordType = "IGNORE";
          name = "tw";
          type = "A,AAAA";
        }
        {
          recordType = "CNAME";
          name = "colocrossing";
          target = homeDdnsTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "*.colocrossing";
          target = "colocrossing.zhyi.cc.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "ml-home-vm";
          target = homeDdnsTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "*.ml-home-vm";
          target = "ml-home-vm.zhyi.cc.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "autoconfig";
          target = homeDdnsTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "flapalerted";
          target = homeDdnsTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "lg";
          target = homeDdnsTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "um";
          target = homeDdnsTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "hydra";
          target = twvmTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "netbox";
          target = twvmTarget;
          ttl = "10m";
        }
      ];
    }
  ];
}
