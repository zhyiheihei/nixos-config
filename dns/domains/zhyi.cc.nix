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

  internalServices = [
    (mkPublicVpsCname "ha")
    (mkPublicVpsCname "autoconfig")
    (mkHomeIngressCname "flapalerted")
    (mkPublicVpsCname "lg")
    (mkPublicVpsCname "um")
    (mkHomeIngressCname "vaults3")
    {
      recordType = "CNAME";
      name = "halo.cnvm";
      target = "cnvm.ltnet.zhyi.cc.";
      ttl = "10m";
    }

    # Monitoring stack (colocrossing)
    {
      recordType = "CNAME";
      name = "prometheus";
      target = "colocrossing.zhyi.cc.";
      ttl = "10m";
    }
    {
      recordType = "CNAME";
      name = "dashboard";
      target = "colocrossing.zhyi.cc.";
      ttl = "10m";
    }
    {
      recordType = "CNAME";
      name = "alert";
      target = "colocrossing.zhyi.cc.";
      ttl = "10m";
    }
    {
      recordType = "CNAME";
      name = "rsync-ci";
      target = "colocrossing.zhyi.cc.";
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
