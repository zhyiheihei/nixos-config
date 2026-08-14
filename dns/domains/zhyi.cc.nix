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
      target = "tencent";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "autoconfig";
      target = "hostdare";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hydra";
      # hydra runs on greencloud; the home-DDNS target was left from the
      # pre-migration layout and made rock5c's siteMonitor fail.
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "um";
      # ml-home-vm retired; private static assets now resolve via the home edge.
      target = "rock5c.ltnet.zhyi.cc.";
      ttl = "1h";
    }

    {
      recordType = "CNAME";
      name = "alert";
      target = "tencent";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "dashboard";
      target = "tencent";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "flapalerted";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "lg";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "netbox";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "prometheus";
      target = "tencent";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "rsync-ci";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "sub";
      target = homeDdnsTarget;
      ttl = "2m";
    }

    {
      recordType = "CNAME";
      name = "couchdb";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "ha";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "qnap";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "vaults3";
      target = homeDdnsTarget;
      ttl = "2m";
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
          address = LT.hosts.hostdare.public.IPv4;
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

        # AhaSend 邮件发送基础设施（此前在 gcore 面板手动添加，
        # 纳入配置使 dnscontrol push 不再删除已验证记录）
        {
          recordType = "TXT";
          name = "@";
          contents = "v=spf1 include:spf.ahasend.com ~all";
          ttl = "10m";
        }
        {
          recordType = "TXT";
          name = "_dmarc";
          contents = "v=DMARC1; p=quarantine; sp=none; adkim=r; aspf=r;";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "ahasend._domainkey";
          target = "2464d18284692720.setup.ahasend.com.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "ahasend2._domainkey";
          target = "c5b1a18d408678b7.setup.ahasend.com.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "psrp";
          target = "rp.ahasend.com.";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "t";
          target = "track.ahasend.com.";
          ttl = "10m";
        }
        # MXRoute 收件 MX（作者原配置，witcher.mxrouting.net）
        {
          recordType = "MX";
          name = "@";
          priority = 10;
          target = "witcher.mxrouting.net.";
        }
        {
          recordType = "MX";
          name = "@";
          priority = 20;
          target = "witcher-relay.mxrouting.net.";
        }
        {
          recordType = "TXT";
          name = "_da-verify-a5191e89fc7b72b3b9e7fe33726b5eb1";
          contents = "domain-verified";
        }

        internalServices
      ];
    }
  ];
}
