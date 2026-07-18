{ ... }:
let
  publicVpsTarget = "cnvm.zhyi.cc.";

  publicServices = [
    "ai"
    "api"
    "attic"
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
    "zerossl"
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
      ++ map (mkCname publicVpsTarget) publicServices;
    }
  ];
}
