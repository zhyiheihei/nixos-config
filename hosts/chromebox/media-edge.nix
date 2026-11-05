{
  config,
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
    "iyuu"
  ];
  qbitPorts = {
    bt = LT.port.qBitTorrent.WebUI;
    pt = LT.port.qBitTorrentPT.WebUI;
    seedbox = LT.port.qBitTorrentSeedbox.WebUI;
  };
  backendHost = {
    peerbanhelper = "chromebox";
    tachidesk = "chromebox";
  };
  mkProxyLocation =
    service:
    if builtins.hasAttr service qbitPorts then
      {
        proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:${builtins.toString qbitPorts.${service}}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        allowCORS = true;
      }
    else
      {
        proxyPass = "https://${service}.${backendHost.${service} or "opi5p"}.zhyi.xin";
        proxyOverrideHost = "${service}.${backendHost.${service} or "opi5p"}.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
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
in
{
  lantian.nginxVhosts =
    builtins.listToAttrs (builtins.concatLists (map mkEdgeVhosts edgeServices))
    // {
      "tachidesk.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = mkProxyLocation "tachidesk";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
      "jellyfin-api.${config.networking.hostName}.zhyi.xin" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."= /Library/SelectableMediaFolders" = {
          proxyPass = "http://127.0.0.1:8096";
          extraConfig = "rewrite ^ /Library/MediaFolders break;";
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };
        accessibleBy = "private";
        noIndex.enable = true;
      };
    };
}
