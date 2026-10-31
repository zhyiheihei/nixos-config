{
  config,
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.xin.";

  internalServices = [
    {
      recordType = "CNAME";
      name = "*.at";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "actual";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ai";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ai-api";
      target = "greencloud-jp.ltnet.zhyi.xin.";
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
      name = "api";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "archiveteam.tencent";
      target = "tencent.ltnet.zhyi.xin.";
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
      name = "at";
      # Tranquil PDS（greencloud）；DID 文档走两级通配子域 <did>.at.zhyi.xin。
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "autoconfig";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "avatar";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "bitwarden";
      target = "volcengine";
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
      name = "cache";
      # atticd 自 greencloud 迁 greencloud-jp（2026-09）；域名随上游 2bcb81f46
      # attic → cache（norm: cache.zhyi.xin → cache.zhyi.xin）
      target = "greencloud-jp";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "cal";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "clawemail.tencent";
      target = "tencent.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "cliproxyapi";
      target = "greencloud-jp.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "cloud";
      # Nextcloud（greencloud-jp）。
      target = "greencloud-jp";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "comments";
      target = "greencloud";
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
      name = "dav";
      # WebDAV on the home OPI5P; public entry follows the author's dav.<domain>
      # exposure (BasicAuth-protected), reached through the home edge.
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "element";
      target = "greencloud";
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
      name = "frpc";
      target = "tencent-cn";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gemini";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "git";
      target = "greencloud-jp";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "google-ssl";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gopher";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ha";
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
      name = "hub.tencent";
      target = "tencent.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hydra";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "id";
      target = "volcengine.ltnet.zhyi.xin.";
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
      name = "jellyfin";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "lg";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-ssl";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-test-ssl";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "login";
      target = "volcengine.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-client";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-federation";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "mc";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "mcsm";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "mcsm-daemon";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "memos";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "nav";
      target = "tencent";
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
      name = "oidc-tester";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "openlist";
      # OpenList 网盘网关（opi5p，公网 8443 TLS 前沿）。
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "palworld";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "pb";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "pic";
      # Lsky Pro 图床（tencent）。
      target = "tencent";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "posts";
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
      name = "prometheus.tencent";
      target = "tencent.ltnet.zhyi.xin.";
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
      target = "greencloud";
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
      name = "rsync-ci";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "s3";
      target = "greencloud-jp";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "searx";
      # LTNET 视图名须与 vhost 名（searx.zhyi.xin）一致，否则 mesh 内解析不到。
      target = "tencent.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "stats";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "sub";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "tachidesk";
      target = "chromebox.ltnet.zhyi.xin.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "tools";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "um";
      # ml-home-vm retired; private static assets now resolve via the home edge.
      target = "rock5c.ltnet.zhyi.xin.";
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
      name = "wallos";
      target = homeDdnsTarget;
      ttl = "2m";
    }
    {
      recordType = "CNAME";
      name = "whois";
      target = "greencloud";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "zerossl";
      target = "greencloud";
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
        # gcore 无 Bunny 脚本记录，上游 GeoScriptedServers "@" 不适用，@ 保持静态 A
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
        {
          recordType = "CNAME";
          name = "www";
          target = "@";
          ttl = "5m";
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

        # 邮件：AhaSend 发送 + MXRoute 收件。上游 Autoconfig/Email/Libravatar/SIP
        # helper 的目标为作者设施（GeoDNSTarget apex 等），fork 保持手动条目。
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
