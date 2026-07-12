{ lib, ... }:
let
  mkTestSSL =
    pair:
    let
      name = lib.head pair;
      prefix = lib.elemAt pair 1;
    in
    lib.nameValuePair "${name}.zhyi.xin" {
      root = "/nix/sync-servers/www/${name}.zhyi.xin";
      locations."/".index = "testssl.htm";
      sslCertificate = "lets-encrypt-zhyi.xin";
      enableCommonLocationOptions = false;
    };
in
{
  lantian.nginxVhosts = builtins.listToAttrs (
    builtins.map mkTestSSL [
      [
        "google-ssl"
        "google"
      ]
      [
        "google-test-ssl"
        "google-test"
      ]
      [
        "letsencrypt-ssl"
        "lets-encrypt"
      ]
      [
        "letsencrypt-test-ssl"
        "lets-encrypt-test"
      ]
      [
        "zerossl"
        "zerossl"
      ]
    ]
  );
}
