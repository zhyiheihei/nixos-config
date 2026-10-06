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
  ];

  activeHosts = lib.filterAttrs (_: host: host.zerotier != null) LT.hosts;
  hostSubdomains = lib.mapAttrsToList (n: _: "${n}.zhyi.xin") activeHosts;

  # Wildcard certs for old host names, so the replacing host can serve
  # 301 redirects on their subdomains (see vhost-replaced-hosts.nix)
  replacedHostSubdomains = builtins.map (n: "${n}.zhyi.xin") (builtins.attrNames LT.replacedHosts);
in
{
  security.acme.certs = lib.mergeAttrsList (
    (builtins.map mkLetsEncryptWildcardCert baseDomains)
    ++ (builtins.map mkZeroSSLWildcardCert baseDomains)
    ++ [
      # ATproto PDS
      (mkZeroSSLWildcardCert "at.zhyi.xin")
    ]
    ++ (builtins.map mkLetsEncryptWildcardCert hostSubdomains)
    ++ (builtins.map mkZeroSSLWildcardCert hostSubdomains)
    ++ (builtins.map mkLetsEncryptWildcardCert replacedHostSubdomains)
    ++ (builtins.map mkZeroSSLWildcardCert replacedHostSubdomains)
  );
}
