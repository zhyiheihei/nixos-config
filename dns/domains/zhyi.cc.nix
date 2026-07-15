{
  config,
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";
  twvmTarget = "tw.zhyi.cc.";

  ownHosts = [
    "colocrossing"
    "jpvm"
    "ml-2700u"
    "ml-builder"
    "ml-home-vm"
    "pve-2700"
    "twvm"
  ];

  hostRecords =
    domain: addressFor:
    lib.concatMap (
      name:
      config.common.hostRecs.mapAddresses {
        name = "${name}.${domain}.";
        addresses = addressFor LT.hosts.${name};
      }
    ) ownHosts;
in
{
  domains = [
    rec {
      domain = "zhyi.cc";
      registrar = "none";
      providers = [ "gcore" ];
      enableWildcard = true;
      records = lib.flatten [
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
          recordType = "A";
          name = "jp";
          address = LT.hosts.jpvm.public.IPv4;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "homepage.ml-home-vm";
          target = twvmTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "archivebox.ml-home-vm";
          target = twvmTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "syncthing.ml-home-vm";
          target = twvmTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "*.ml-home-vm";
          target = homeDdnsTarget;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "*";
          target = homeDdnsTarget;
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

        (builtins.filter
          (record: !(record.recordType == "CNAME" && record.name == "*.ml-home-vm.zhyi.cc."))
          (hostRecords domain (
            host: if config.common.hostRecs.hasPublicIP host then host.public else host.ltnet
          ))
        )
        (hostRecords "ltnet.${domain}" (host: host.ltnet))
      ];
    }
  ];
}
