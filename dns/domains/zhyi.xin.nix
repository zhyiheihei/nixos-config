{ ... }:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";
  publicVpsTarget = "cnvm.zhyi.cc.";

  homeServices = [
    "ai"
    "attic"
    "gemini"
    "google-ssl"
    "google-test-ssl"
    "gopher"
    "lemmy"
    "letsencrypt-ssl"
    "letsencrypt-test-ssl"
    "mail"
    "matrix"
    "matrix-client"
    "matrix-federation"
    "pb"
    "rsshub"
    "zerossl"
  ];

  publicVpsServices = [
    "api"
    "autoconfig"
    "avatar"
    "bitwarden"
    "cal"
    "comments"
    "element"
    "filebox"
    "git"
    "id"
    "index"
    "index-helper"
    "login"
    "posts"
    "rss"
    "sso"
    "stats"
    "tools"
    "whois"
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
      enableWildcard = true;
      records = [
        {
          recordType = "IGNORE";
          name = "@";
          type = "A,AAAA";
        }
        {
          recordType = "IGNORE";
          name = "www";
          type = "A,AAAA";
        }
        {
          recordType = "IGNORE";
          name = "hub";
          type = "A,AAAA";
        }
        {
          recordType = "IGNORE";
          name = "hk";
          type = "A,AAAA";
        }
        {
          recordType = "A";
          name = "*";
          address = "101.96.199.157";
          ttl = "10m";
        }
      ]
      ++ map (mkCname homeDdnsTarget) homeServices
      ++ map (mkCname publicVpsTarget) (publicVpsServices ++ [ "n8n" ]);
    }
  ];
}
