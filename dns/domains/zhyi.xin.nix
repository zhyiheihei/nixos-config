{
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.xin.";

  internalServices = [
    {
      recordType = "CNAME";
      name = "ai";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ai-api";
      target = "hostdare.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "alert";
      target = "tencent.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "api";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "asf";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "attic";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "autoconfig";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "avatar";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "bitwarden";
      target = "volcengine.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "books";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "cal";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "dashboard";
      target = "tencent.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "dav";
      # WebDAV on the home OPI5P; public entry follows the author's dav.<domain>
      # exposure (BasicAuth-protected), reached through the home edge.
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "dsh";
      # DSH web UI on the tencent VPS; Dex OIDC-protected (oauth2-proxy).
      target = "tencent.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "element";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "filebox";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "flapalerted";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gemini";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "git";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "google-ssl";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "google-test-ssl";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gopher";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ha";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hidden";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hydra";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "id";
      target = "volcengine.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "immich";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "index";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "index-helper";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "jellyfin";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "lemmy";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-ssl";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-test-ssl";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "login";
      target = "volcengine.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "mail";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-client";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-federation";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "nav";
      target = "tencent.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "n8n";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "netbox";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "pb";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "prometheus";
      target = "tencent.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "qnap";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "rss";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "rsshub";
      target = "greencloud.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "stats";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "sub";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "tachidesk";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "tools";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "vaults3";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "whois";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "www";
      target = "@";
      ttl = "5m";
    }
    {
      recordType = "CNAME";
      name = "zerossl";
      target = "greencloud.zhyi.xin.";
      ttl = "1h";
    }

    # Records formerly under the old private subdomain, folded into zhyi.xin.
    {
      recordType = "CNAME";
      name = "um";
      # ml-home-vm retired; private static assets now resolve via the home edge.
      target = "rock5c.ltnet.zhyi.xin.";
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
      name = "rsync-ci";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "halo.volcengine";
      target = "volcengine.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "searx.tencent";
      target = "tencent.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "metapi.tencent";
      target = "tencent.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hub.tencent";
      target = "tencent.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "prometheus.tencent";
      target = "tencent.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "n8n-bridge.greencloud";
      target = "greencloud.ltnet.zhyi.xin.";
      ttl = "1h";
    }
  ];
in
{
  domains = [
    rec {
      domain = "zhyi.xin";
      registrar = "none";
      providers = [ "gcore" ];
      enableWildcard = true;
      records = lib.flatten [
        {
          recordType = "A";
          name = "@";
          address = LT.hosts.volcengine.public.IPv4;
          ttl = "10m";
        }
        {
          recordType = "HTTPS";
          name = "@";
          priority = 1;
          target = ".";
          modifiers = "alpn=h3,h2";
        }

        config.common.hostRecs.CAA
        (config.common.hostRecs.Normal "${domain}.")

        # site.zhyi.xin is the H28K remote-site router's dynamic WAN, updated
        # by hosts/h28k/ddns_gcore.py; keep dnscontrol from touching it.
        {
          recordType = "IGNORE";
          name = "site";
          type = "A,AAAA";
        }
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
