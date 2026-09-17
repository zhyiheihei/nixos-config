{
  lib,
  LT,
  ...
}:
let
  opiAddress = LT.hosts.opi5p.interconnect.IPv4;
  dragonAddress = LT.hosts.dragon-q8b.interconnect.IPv4;
  # 服务在 opi5p 上的走 opi5p 回源，已迁 dragon-q8b 的走 dragon-q8b。
  mkBackend = backendHost: hostAddress: {
    proxyPass = "https://${hostAddress}";
    proxyOverrideHost = backendHost;
    proxyWebsockets = true;
    proxyNoTimeout = true;
    extraConfig = ''
      proxy_ssl_server_name on;
      proxy_ssl_name ${backendHost};
    '';
  };
  fixedFrontends = {
    "asf.zhyi.xin" = {
      backend = "asf.zhyi.xin";
      address = opiAddress;
    };
    "books.zhyi.xin" = {
      backend = "books.zhyi.xin";
      address = opiAddress;
    };
    "dav.zhyi.xin" = {
      backend = "dav.zhyi.xin";
      address = opiAddress;
    };
    "immich.zhyi.xin" = {
      backend = "immich.zhyi.xin";
      address = opiAddress;
    };
    # OpenList 后端 vhost 在 opi5p（OAuth 在后端层），此处同 asf 模式前置
    # 一层 OAuth：内网 443 入口经 router 兜底 DNAT 落到本机，缺失登记时
    # 会被默认 server 的 snakeoil 证书拦住。
    "openlist.zhyi.xin" = {
      backend = "openlist.zhyi.xin";
      address = opiAddress;
    };
    "memos.zhyi.xin" = {
      backend = "memos.zhyi.xin";
      address = dragonAddress;
    };
    "wallos.zhyi.xin" = {
      backend = "wallos.zhyi.xin";
      address = dragonAddress;
    };
  };
  mkFixedFrontend = frontend: cfg: {
    locations."/" =
      (mkBackend cfg.backend cfg.address)
      // lib.optionalAttrs (builtins.elem frontend [
        "books.zhyi.xin"
        "dav.zhyi.xin"
      ]) { enableBasicAuth = true; }
      // lib.optionalAttrs (builtins.elem frontend [
        "asf.zhyi.xin"
        "openlist.zhyi.xin"
      ]) { enableOAuth = true; };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };
in
{
  lantian.nginxVhosts = lib.mapAttrs' (
    frontend: cfg: lib.nameValuePair frontend (mkFixedFrontend frontend cfg)
  ) fixedFrontends;
}
