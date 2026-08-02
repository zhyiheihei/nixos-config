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
    "filebox.zhyi.xin" = "filebox.zhyi.xin";
    "ha.zhyi.cc" = "ha.zhyi.cc";
    "immich.zhyi.xin" = "immich.zhyi.xin";
    "index.zhyi.xin" = "index.zhyi.xin";
    "index-helper.zhyi.xin" = "index-helper.zhyi.xin";
  };
  legacyFrontends = {
    "archivebox.ml-home-vm.zhyi.cc" = "archivebox.opi5p.zhyi.cc";
    "dav.ml-home-vm.zhyi.cc" = "dav.opi5p.zhyi.cc";
    "freshrss.ml-home-vm.zhyi.cc" = "freshrss.opi5p.zhyi.cc";
    "linkwarden.ml-home-vm.zhyi.cc" = "linkwarden.opi5p.zhyi.cc";
    "memos.ml-home-vm.zhyi.cc" = "memos.opi5p.zhyi.cc";
    "searx.ml-home-vm.zhyi.cc" = "searx.opi5p.zhyi.cc";
    "syncthing.ml-home-vm.zhyi.cc" = "syncthing.opi5p.zhyi.cc";
  };
  mkFrontend = certificate: backendHost: {
    locations."/" = mkBackend backendHost;
    sslCertificate = certificate;
    noIndex.enable = true;
  };
  mkFixedFrontend = frontend: backend: {
    locations."/" =
      (mkBackend backend)
      // lib.optionalAttrs (frontend == "books.zhyi.xin") { enableBasicAuth = true; }
      // lib.optionalAttrs (
        builtins.elem frontend [
          "asf.zhyi.xin"
          "ha.zhyi.cc"
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
    // lib.mapAttrs (
      _: backend:
      (mkFrontend "lets-encrypt-ml-home-vm.zhyi.cc" backend)
      // { accessibleBy = "private"; }
    ) legacyFrontends;
}
