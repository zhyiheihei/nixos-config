{ ... }:
let
  homeDdnsTarget = "home-ddns.zhyi.cc.";
  twvmTarget = "tw.zhyi.cc.";

  homeServices = [
    "ai"
    "attic"
    "gemini"
    "git"
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
    "n8n"
    "pb"
    "rsshub"
    "zerossl"
  ];

  twvmServices = [
    "api"
    "autoconfig"
    "avatar"
    "cal"
    "comments"
    "element"
    "id"
    "login"
    "posts"
    "rss"
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
      enableWildcard = false;
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
          recordType = "IGNORE";
          name = "*";
          type = "A,AAAA";
        }
      ]
      ++ map (mkCname homeDdnsTarget) homeServices
      ++ map (mkCname twvmTarget) twvmServices;
    }
  ];
}
