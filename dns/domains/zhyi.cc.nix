{
  config,
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";
  publicVpsTarget = "tw.zhyi.cc.";

  mkPublicVpsCname = name: {
    recordType = "CNAME";
    inherit name;
    target = publicVpsTarget;
    ttl = "10m";
  };

  mkPublicVpsRecord = name: {
    recordType = "GEO";
    inherit name;
    ttl = "2m";
    filter = n: _: builtins.elem n [ "jpvm" "twvm" ];
    ipv4Only = true;
    healthcheck = "${name}.zhyi.cc";
    healthcheckFrequency = 300;
    gcoreFilters = "weighted_shuffle,false;first_n,false,1";
    weights = {
      jpvm = 100;
      twvm = 1;
    };
  };

  ownHosts = [
    "colocrossing"
    "jpvm"
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
          name = "wg-home";
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
        (mkPublicVpsCname "homepage.ml-home-vm")
        (mkPublicVpsCname "archivebox.ml-home-vm")
        (mkPublicVpsCname "syncthing.ml-home-vm")
        (mkPublicVpsCname "halo.ml-home-vm")
        (mkPublicVpsCname "linkwarden.ml-home-vm")
        (mkPublicVpsCname "excalidraw.ml-home-vm")
        (mkPublicVpsCname "freshrss.ml-home-vm")
        (mkPublicVpsCname "memos.ml-home-vm")
        (mkPublicVpsCname "vertex.ml-home-vm")
        (mkPublicVpsRecord "ha")
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
        (mkPublicVpsCname "hydra")
        (mkPublicVpsCname "netbox")
        (mkPublicVpsCname "sub")

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
