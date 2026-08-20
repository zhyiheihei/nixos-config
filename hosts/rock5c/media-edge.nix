{
  config,
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
  qbitPorts = {
    bt = LT.port.qBitTorrent.WebUI;
    pt = LT.port.qBitTorrentPT.WebUI;
    seedbox = LT.port.qBitTorrentSeedbox.WebUI;
  };
  mkProxyLocation = service:
    if builtins.hasAttr service qbitPorts then {
      proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:${builtins.toString qbitPorts.${service}}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      allowCORS = true;
    } else {
      proxyPass = "https://${service}.opi5p.zhyi.cc";
      proxyOverrideHost = "${service}.opi5p.zhyi.cc";
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
      # MoviePilot container needs an HTTP-only Jellyfin API entry; the Jellyfin
      # server has moved to macmini (192.168.0.54:8096, VideoToolbox). This vhost
      # stays on rock5c with its stable name so MoviePilot's --add-host continues
      # to point at rock5c, but the backend now proxies to mac. The `/Library/
      # SelectableMediaFolders` rewrite is still needed by MoviePilot's media
      # library scan to present the union of media-radarr/media-sonarr folders.
      "jellyfin-api.${config.networking.hostName}.zhyi.cc" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."= /Library/SelectableMediaFolders" = {
          proxyPass = "http://${LT.hosts.macmini.interconnect.IPv4}:8096";
          extraConfig = "rewrite ^ /Library/MediaFolders break;";
        };
        locations."/" = {
          proxyPass = "http://${LT.hosts.macmini.interconnect.IPv4}:8096";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };
        accessibleBy = "private";
        noIndex.enable = true;
      };
    };
}
