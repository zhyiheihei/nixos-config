{
  LT,
  ...
}:
let
  # 公网名里后端不在本机的部分：WAN 入口统一落本机，仍按原主机收口。
  # 走 https + SNI 保留原主机的 vhost 选择，模板与 hosts/opi5p 的 memos/wallos 一致。
  tlsProxies = {
    asf = LT.hosts.opi5p.interconnect.IPv4;
    books = LT.hosts.opi5p.interconnect.IPv4;
    dav = LT.hosts.opi5p.interconnect.IPv4;
    openlist = LT.hosts.opi5p.interconnect.IPv4;
    mcsm = LT.hosts.pve-5700u.interconnect.IPv4;
    mcsm-daemon = LT.hosts.pve-5700u.interconnect.IPv4;
  };
  plainProxies = {
    qnap = "http://192.168.0.40:8080";
    vaults3 = "http://${LT.hosts.router.interconnect.IPv4}:9000";
  };
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
    builtins.foldl' (acc: n: acc // mkTlsVhost n tlsProxies.${n}) { } (builtins.attrNames tlsProxies)
    // builtins.foldl' (acc: n: acc // mkPlainVhost n plainProxies.${n}) { } (
      builtins.attrNames plainProxies
    );
}
