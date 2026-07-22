{ LT, ... }:
let
  publicVpsTarget = "home-ddns.zhyi.cc.";

  publicServices = [
    "ai"
    "api"
    "autoconfig"
    "avatar"
    "cal"
    "element"
    "filebox"
    "gemini"
    "git"
    "google-ssl"
    "google-test-ssl"
    "gopher"
    "hidden"
    "homepage"
    "index"
    "index-helper"
    "lemmy"
    "letsencrypt-ssl"
    "letsencrypt-test-ssl"
    "mail"
    "matrix"
    "matrix-client"
    "matrix-federation"
    "n8n"
    "pb"
    "posts"
    "rss"
    "rsshub"
    "stats"
    "tools"
    "whois"
    "www"
    "zerossl"
  ];

  cnvmServices = [
    "attic"
    "bitwarden"
    "id"
    "login"
  ];

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
      records = [
        {
          recordType = "A";
          name = "@";
          address = LT.hosts.cnvm.public.IPv4;
          ttl = "10m";
        }
      ]
      ++ map (mkCname publicVpsTarget) publicServices
      ++ map (mkCname "cnvm.zhyi.cc.") cnvmServices;
    }
  ];
}
