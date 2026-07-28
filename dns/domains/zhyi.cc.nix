{
  config,
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";

  internalServices = [
    {
      recordType = "CNAME";
      name = "ai-api";
      target = "jpvm";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "autoconfig";
      target = "jpvm";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hydra";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "um";
      target = "ml-home-vm.ltnet.zhyi.cc.";
      ttl = "1h";
    }

    {
      recordType = "CNAME";
      name = "alert";
      target = "colocrossing";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "dashboard";
      target = "colocrossing";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "flapalerted";
      target = "colocrossing";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "lg";
      target = "colocrossing";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "netbox";
      target = "colocrossing";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "prometheus";
      target = "colocrossing";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "rsync-ci";
      target = "colocrossing";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "sub";
      target = homeDdnsTarget;
      ttl = "1h";
    }

    {
      recordType = "CNAME";
      name = "couchdb";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ha";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "qnap";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "vaults3";
      target = homeDdnsTarget;
      ttl = "1h";
    }

    {
      recordType = "CNAME";
      name = "halo.cnvm";
      target = "cnvm.ltnet.zhyi.cc.";
      ttl = "1h";
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
