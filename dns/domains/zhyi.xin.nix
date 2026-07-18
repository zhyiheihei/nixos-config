{ LT, ... }:
let
  publicVpsTarget = "cnvm.zhyi.cc.";

  publicServices = [
    "ai"
    "api"
    "autoconfig"
    "avatar"
    "bitwarden"
    "cal"
    "comments"
    "element"
    "filebox"
    "gemini"
    "git"
    "google-ssl"
    "google-test-ssl"
    "gopher"
    "id"
    "index"
    "index-helper"
    "lemmy"
    "letsencrypt-ssl"
    "letsencrypt-test-ssl"
    "login"
    "mail"
    "matrix"
    "matrix-client"
    "matrix-federation"
    "n8n"
    "pb"
    "posts"
    "rss"
    "rsshub"
    "sso"
    "stats"
    "tools"
    "whois"
    "www"
    "zerossl"
  ];

  highTrafficServices = [ "attic" ];

  mkCname = target: name: {
    recordType = "CNAME";
    inherit name target;
    ttl = "10m";
  };

in
{
  domains = [
    {
      domain = "zhyi.xin";
      registrar = "none";
      providers = [ "gcore" ];
      enableWildcard = true;
      records = [
        {
          recordType = "A";
          name = "@";
          address = LT.hosts.cnvm.public.IPv4;
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "*";
          target = publicVpsTarget;
          ttl = "10m";
        }
      ]
      ++ map (mkCname publicVpsTarget) publicServices
      ++ map (mkCname "home-ingress.zhyi.cc.") highTrafficServices;
    }
  ];
}
