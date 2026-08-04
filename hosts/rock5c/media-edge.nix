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
      "handbrake.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.HandBrake}";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
}
