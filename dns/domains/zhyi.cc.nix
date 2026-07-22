{
  config,
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";
  publicVpsTarget = "jpvm.zhyi.cc.";

  mkPublicVpsCname = name: {
    recordType = "CNAME";
    inherit name;
    target = publicVpsTarget;
    ttl = "10m";
  };

  mkHomeIngressCname = name: {
    recordType = "CNAME";
    inherit name;
    target = homeDdnsTarget;
    ttl = "10m";
  };

  ownHosts = [
    "cnvm"
    "colocrossing"
    "jpvm"
    "sgvm"
    "ml-builder"
    "ml-home-vm"
    "ml-2700"
    "usvm"
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
          recordType = "A";
          name = "@";
          address = LT.hosts.jpvm.public.IPv4;
          ttl = "10m";
        }
        (mkPublicVpsCname "archivebox.ml-home-vm")
        (mkPublicVpsCname "syncthing.ml-home-vm")
        {
          recordType = "CNAME";
          name = "halo.cnvm";
          target = "cnvm.ltnet.zhyi.cc.";
          ttl = "10m";
        }
        (mkPublicVpsCname "linkwarden.ml-home-vm")
        (mkPublicVpsCname "excalidraw.ml-home-vm")
        (mkPublicVpsCname "freshrss.ml-home-vm")
        (mkPublicVpsCname "memos.ml-home-vm")
        (mkPublicVpsCname "vertex.ml-home-vm")
        (mkPublicVpsCname "ha")
        {
          recordType = "CNAME";
          name = "*.ml-home-vm";
          target = "ml-home-vm.ltnet.zhyi.cc.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "*";
          target = publicVpsTarget;
          ttl = "10m";
        }
        (mkPublicVpsCname "autoconfig")
        (mkPublicVpsCname "flapalerted")
        (mkPublicVpsCname "lg")
        (mkPublicVpsCname "um")
        (mkPublicVpsCname "hydra")
        (mkPublicVpsCname "netbox")
        (mkPublicVpsCname "sub")

        # Monitoring stack (sgvm)
        {
          recordType = "CNAME";
          name = "prometheus";
          target = "sgvm.zhyi.cc.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "dashboard";
          target = "sgvm.zhyi.cc.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "alert";
          target = "sgvm.zhyi.cc.";
          ttl = "10m";
        }

        # High-volume cache data stays on the home ingress.
        (mkHomeIngressCname "vaults3")

        (builtins.filter
          (
            record:
            !(record.recordType == "CNAME" && record.name == "*.ml-home-vm.zhyi.cc.")
          )
          (hostRecords domain (
            host: if config.common.hostRecs.hasPublicIP host then host.public else host.ltnet
          ))
        )
        (hostRecords "ltnet.${domain}" (host: host.ltnet))
      ];
    }
  ];
}
