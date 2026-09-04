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
in
{
  security.acme.certs = lib.mergeAttrsList (
    (builtins.map mkLetsEncryptWildcardCert baseDomains)
    ++ (builtins.map mkZeroSSLWildcardCert baseDomains)
    ++ [
      # ATproto PDS（tranquil-pds.nix：at.zhyi.xin 与 DID 通配子域），
      # 同上游 base-domains 的 at.lantian.pub 条目。
      (mkZeroSSLWildcardCert "at.zhyi.xin")
    ]
    ++ (builtins.map mkLetsEncryptWildcardCert hostSubdomains)
    ++ (builtins.map mkZeroSSLWildcardCert hostSubdomains)
  );
}
