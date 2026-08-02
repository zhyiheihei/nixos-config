{
  lib,
  LT,
  ...
}:
let
  edgeServices = [
    "bt"
    "pt"
    "seedbox"
    "vertex"
    "sonarr"
    "radarr"
    "bazarr"
    "prowlarr"
    "jproxy"
    "peerbanhelper"
    "bitmagnet"
    "iyuu"
  ];
  mkProxyLocation = service: {
    proxyPass = "https://${service}.opi5p.zhyi.cc";
    proxyOverrideHost = "${service}.opi5p.zhyi.cc";
    proxyWebsockets = true;
    proxyNoTimeout = true;
  }
  // lib.optionalAttrs (builtins.elem service [
    "bt"
    "pt"
    "seedbox"
  ]) { allowCORS = true; };
  mkEdgeVhosts = service: [
    {
      name = "${service}.ml-home-vm.zhyi.cc";
      value = {
        locations."/" = mkProxyLocation service;
        accessibleBy = "private";
        sslCertificate =
          if service == "iyuu" then
            "lets-encrypt-ml-home-vm.zhyi.cc"
          else
            "zerossl-ml-home-vm.zhyi.cc";
        noIndex.enable = true;
      };
    }
    {
      name = "${service}.localhost";
      value = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = mkProxyLocation service;
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    }
  ];
  backendLocation = backendHost: {
    proxyPass = "http://${LT.hosts.opi5p.interconnect.IPv4}";
    proxyOverrideHost = backendHost;
    proxyWebsockets = true;
    proxyNoTimeout = true;
  };
in
{
  imports = [ ../../nixos/optional-apps/jellyfin.nix ];

  lantian.nginxVhosts =
    builtins.listToAttrs (builtins.concatLists (map mkEdgeVhosts edgeServices))
    // {
      "tachidesk.zhyi.xin" = {
        locations."/" = (backendLocation "tachidesk-backend.opi5p.zhyi.cc") // {
          enableBasicAuth = true;
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "tachidesk.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = backendLocation "tachidesk-backend.opi5p.zhyi.cc";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
      "handbrake.ml-home-vm.zhyi.cc" = {
        locations."/" = backendLocation "handbrake-backend.opi5p.zhyi.cc";
        accessibleBy = "private";
        sslCertificate = "lets-encrypt-ml-home-vm.zhyi.cc";
        noIndex.enable = true;
      };
      "handbrake.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = backendLocation "handbrake-backend.opi5p.zhyi.cc";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
}
