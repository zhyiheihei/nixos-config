{
  config,
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";
  colocrossingTarget = "colocrossing.zhyi.cc.";
  jpvmTarget = "jpvm.zhyi.cc.";
  mlHomeVmLtnetTarget = "ml-home-vm.ltnet.zhyi.cc.";

  mkCname = target: name: {
    recordType = "CNAME";
    inherit name;
    inherit target;
    ttl = "10m";
  };

  internalServices = [
    (mkCname jpvmTarget "ai-api")
    (mkCname jpvmTarget "autoconfig")
    (mkCname jpvmTarget "hydra")
    (mkCname mlHomeVmLtnetTarget "um")

    (mkCname colocrossingTarget "alert")
    (mkCname colocrossingTarget "dashboard")
    (mkCname colocrossingTarget "flapalerted")
    (mkCname colocrossingTarget "lg")
    (mkCname colocrossingTarget "netbox")
    (mkCname colocrossingTarget "prometheus")
    (mkCname colocrossingTarget "rsync-ci")
    (mkCname colocrossingTarget "sub")

    (mkCname homeDdnsTarget "couchdb")
    (mkCname homeDdnsTarget "ha")
    (mkCname homeDdnsTarget "qnap")
    (mkCname homeDdnsTarget "vaults3")

    {
      recordType = "CNAME";
      name = "halo.cnvm";
      target = "cnvm.ltnet.zhyi.cc.";
      ttl = "10m";
    }
  ];
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
          recordType = "A";
          name = "@";
          address = LT.hosts.jpvm.public.IPv4;
          ttl = "10m";
        }
        {
          recordType = "HTTPS";
          name = "@";
          priority = 1;
          target = ".";
          modifiers = "alpn=h3,h2";
        }
        {
          recordType = "CNAME";
          name = "www";
          target = "@";
          ttl = "5m";
        }

        config.common.hostRecs.CAA
        (config.common.hostRecs.Normal "${domain}.")

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

        (config.common.hostRecs.LTNet "ltnet.${domain}.")
        (config.common.hostRecs.DN42 "dn42.${domain}.")

        internalServices
      ];
    }
  ];
}
