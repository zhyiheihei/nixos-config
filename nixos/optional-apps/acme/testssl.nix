{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (pkgs.callPackage ./common.nix { inherit config; })
    mkLetsEncryptCert
    mkLetsEncryptTestCert
    mkZeroSSLCert
    ;
in
{
  security.acme.certs = lib.mergeAttrsList [
    # Google Public CA EAB credentials expire after seven days and require
    # external account provisioning. Keep these probes disabled until there
    # is an intentional credential-rotation workflow.
    (mkLetsEncryptCert "letsencrypt-ssl.zhyi.xin")
    (mkLetsEncryptTestCert "letsencrypt-test-ssl.zhyi.xin")
    (mkZeroSSLCert "zerossl.zhyi.xin")
  ];
}
