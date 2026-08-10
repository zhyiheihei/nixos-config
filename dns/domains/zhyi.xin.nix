{
  lib,
  LT,
  ...
}:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";

  internalServices = [
    {
      recordType = "CNAME";
      name = "ai";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "api";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "asf";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "attic";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "autoconfig";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "avatar";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "bitwarden";
      target = "cnvm.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "books";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "cal";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "element";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "filebox";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gemini";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "git";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "google-ssl";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "google-test-ssl";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "gopher";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "hidden";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "id";
      target = "cnvm.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "immich";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "index";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "index-helper";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "jellyfin";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "lemmy";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-ssl";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "letsencrypt-test-ssl";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "login";
      target = "cnvm.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "mail";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-client";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "matrix-federation";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "n8n";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "pb";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "posts";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "rss";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "rsshub";
      target = "colocrossing.ltnet.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "stats";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "tachidesk";
      target = homeDdnsTarget;
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "tools";
      target = "colocrossing.zhyi.cc.";
      ttl = "1h";
    }
    {
      recordType = "CNAME";
      name = "whois";
      target = "colocrossing.zhyi.cc.";
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
      target = "colocrossing.zhyi.cc.";
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
          address = LT.hosts.cnvm.public.IPv4;
          ttl = "10m";
        }

        internalServices
      ];
    }
  ];
}
