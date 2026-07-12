{
  LT,
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (pkgs.callPackage ./common.nix { inherit config; })
    mkLetsEncryptWildcardCert
    mkZeroSSLWildcardCert
    ;

  baseDomains = [
    "zhyi.xin"
    "zhyi.cc"
    "moliy.site"
  ];

  hostSubdomains = lib.mapAttrsToList (n: _: "${n}.zhyi.cc") LT.hosts;
in
{
  security.acme.certs = lib.mergeAttrsList (
    (builtins.map mkLetsEncryptWildcardCert baseDomains)
    ++ (builtins.map mkZeroSSLWildcardCert baseDomains)
    ++ (builtins.map mkLetsEncryptWildcardCert hostSubdomains)
    ++ (builtins.map mkZeroSSLWildcardCert hostSubdomains)
  );
}
