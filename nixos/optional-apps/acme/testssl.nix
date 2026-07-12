{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (pkgs.callPackage ./common.nix { inherit config; })
    mkGoogleCert
    mkGoogleTestCert
    mkLetsEncryptCert
    mkLetsEncryptTestCert
    mkZeroSSLCert
    ;
in
{
  security.acme.certs = lib.mergeAttrsList [
    (mkGoogleCert "google-ssl.zhyi.xin")
    (mkGoogleTestCert "google-test-ssl.zhyi.xin")
    (mkLetsEncryptCert "letsencrypt-ssl.zhyi.xin")
    (mkLetsEncryptTestCert "letsencrypt-test-ssl.zhyi.xin")
    (mkZeroSSLCert "zerossl.zhyi.xin")
  ];
}
