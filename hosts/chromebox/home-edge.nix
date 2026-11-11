{
  lib,
  LT,
  ...
}:
let
  # 公网名里后端不在本机的部分：WAN 入口统一落本机，仍按原主机收口。
  # 走 https + SNI 让上游 vhost 按域名自行选择。
  tlsProxies = {
    dav = LT.hosts.opi5p.interconnect.IPv4;
    mcsm = LT.hosts.ml-builder.interconnect.IPv4;
    mcsm-daemon = LT.hosts.ml-builder.interconnect.IPv4;
  };
  plainProxies = {
    qnap = "http://192.168.0.40:8080";
    vaults3 = "http://${LT.hosts.router.interconnect.IPv4}:9000";
  };
  # 本机自托管的公网名：模块默认 private，这里统一放行公网入口。
  publicServices = [
    "asf"
    "books"
    "openlist"
    "memos"
    "wallos"
    "nexttodo"
  ];
  mkTlsVhost = name: upstream: {
    "${name}.zhyi.xin" = {
      locations."/" = {
        proxyPass = "https://${upstream}";
        proxyOverrideHost = "${name}.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name ${name}.zhyi.xin;
        '';
      };
      accessibleBy = "public";
      noIndex.enable = true;
    };
  };
  mkPlainVhost = name: upstream: {
    "${name}.zhyi.xin" = {
      locations."/" = {
        proxyPass = upstream;
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
      accessibleBy = "public";
      noIndex.enable = true;
    };
  };
in
{
  imports = [
    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/vlmcsd.nix

    ./media-edge.nix
  ];

  lantian.nginxVhosts =
    lib.genAttrs (map (name: "${name}.zhyi.xin") publicServices) (_: {
      accessibleBy = lib.mkForce "public";
    })
    // builtins.foldl' (acc: n: acc // mkTlsVhost n tlsProxies.${n}) { } (builtins.attrNames tlsProxies)
    // builtins.foldl' (acc: n: acc // mkPlainVhost n plainProxies.${n}) { } (
      builtins.attrNames plainProxies
    );
}
