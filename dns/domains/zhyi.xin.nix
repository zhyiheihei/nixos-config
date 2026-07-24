{ LT, ... }:
let
  publicVpsTarget = "colocrossing.zhyi.cc.";

  publicServices = [
    "api"
    "asf"
    "autoconfig"
    "avatar"
    "books"
    "cal"
    "element"
    "filebox"
    "gemini"
    "git"
    "google-ssl"
    "google-test-ssl"
    "gopher"
    "hidden"
    "immich"
    "index"
    "index-helper"
    "jellyfin"
    "lemmy"
    "letsencrypt-ssl"
    "letsencrypt-test-ssl"
    "mail"
    "matrix"
    "matrix-client"
    "matrix-federation"
    "pb"
    "posts"
    "rss"
    "rsshub"
    "stats"
    "tachidesk"
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
      ++ map (mkCname "cnvm.zhyi.cc.") cnvmServices
      ++ [
        # AI services run on colocrossing.
        (mkCname "colocrossing.zhyi.cc." "ai")
        (mkCname "colocrossing.zhyi.cc." "n8n")
      ];
    }
  ];
}
