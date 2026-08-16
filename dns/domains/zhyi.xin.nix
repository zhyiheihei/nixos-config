{
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";

  internalServices = [    {
      recordType = "CNAME";
      name = "ai";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ai-api";
      target = "hostdare.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "alert";
      target = "tencent.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "api";
      target = "greencloud.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "autoconfig";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "avatar";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "bitwarden";
      target = "volcengine.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "dashboard";
      target = "tencent.zhyi.cc.";
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
      target = "tencent.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "element";
      target = "greencloud.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gemini";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "git";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "google-ssl";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "google-test-ssl";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gopher";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "ha";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hidden";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hydra";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "id";
      target = "volcengine.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-ssl";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-test-ssl";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "login";
      target = "volcengine.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "mail";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-client";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-federation";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "n8n";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "netbox";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "pb";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "prometheus";
      target = "tencent.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "rsshub";
      target = "greencloud.ltnet.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "stats";
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "sub";
      target = "greencloud.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
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
      target = "greencloud.zhyi.cc.";
      ttl = "1h";
    }
  ];
in
{
  domains = [
    {
      domain = "zhyi.xin";
      registrar = "none";
      providers = [ "gcore" ];
      records = lib.flatten [
        {
          recordType = "A";
          name = "@";
          address = LT.hosts.volcengine.public.IPv4;
          ttl = "10m";
        }

        # site.zhyi.xin is the H28K remote-site router's dynamic WAN, updated
        # by hosts/h28k/ddns_gcore.py; keep dnscontrol from touching it.
        {
          recordType = "IGNORE";
          name = "site";
          type = "A,AAAA";
        }

        internalServices
      ];
    }
  ];
}
