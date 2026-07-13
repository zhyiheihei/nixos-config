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
          recordType = "NO_PURGE";
          name = "@";
        }
      ]
      ++ map (mkCname homeDdnsTarget) homeServices
      ++ map (mkCname twvmTarget) twvmServices;
    }
  ];
}
