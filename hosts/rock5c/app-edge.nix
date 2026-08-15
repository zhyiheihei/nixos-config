{
  lib,
  LT,
  ...
}:
let
  opiAddress = LT.hosts.opi5p.interconnect.IPv4;
  mkBackend = backendHost: {
    proxyPass = "https://${opiAddress}";
    proxyOverrideHost = backendHost;
    proxyWebsockets = true;
    proxyNoTimeout = true;
    extraConfig = ''
      proxy_ssl_server_name on;
      proxy_ssl_name ${backendHost};
    '';
  };
  fixedFrontends = {
    "asf.zhyi.xin" = "asf.zhyi.xin";
    "books.zhyi.xin" = "books.zhyi.xin";
    "dav.zhyi.xin" = "dav.zhyi.xin";
    "filebox.zhyi.xin" = "filebox.zhyi.xin";
    "immich.zhyi.xin" = "immich.zhyi.xin";
    "index.zhyi.xin" = "index.zhyi.xin";
    "index-helper.zhyi.xin" = "index-helper.zhyi.xin";
  };
  mkFixedFrontend = frontend: backend: {
    locations."/" =
      (mkBackend backend)
      // lib.optionalAttrs (
        builtins.elem frontend [
          "books.zhyi.xin"
          "dav.zhyi.xin"
        ]
      ) { enableBasicAuth = true; }
      // lib.optionalAttrs (
        builtins.elem frontend [
          "asf.zhyi.xin"
          "index.zhyi.xin"
          "index-helper.zhyi.xin"
        ]
      ) { enableOAuth = true; };
    sslCertificate =
      if lib.hasSuffix ".zhyi.xin" frontend then "lets-encrypt-zhyi.xin" else "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
in
{
  lantian.nginxVhosts =
    lib.mapAttrs' (
      frontend: backend:
      lib.nameValuePair frontend (mkFixedFrontend frontend backend)
    ) fixedFrontends
    ;
}
