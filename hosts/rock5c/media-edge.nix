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
  # 边缘反代的后端所在主机。bitmagnet 于 2026-08-28、peerbanhelper 于
  # 2026-08、tachidesk 于 2026-09-04 迁至 dragon-q8b；其余仍在 opi5p。
  backendHost = {
    bitmagnet = "dragon-q8b";
    peerbanhelper = "dragon-q8b";
    tachidesk = "dragon-q8b";
  };
  mkProxyLocation = service:
    if builtins.hasAttr service qbitPorts then {
      proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:${builtins.toString qbitPorts.${service}}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      allowCORS = true;
    } else {
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
      # tachidesk 跑在 dragon-q8b（模块 vhost 与上游逐字对齐：
      # tachidesk.zhyi.xin + basicAuth），边缘直连其机器域，不再经
      # opi5p 的 tachidesk-backend 死跳（2026-09-04 撤除跨机 -backend）。
      "tachidesk.zhyi.xin" = {
        locations."/" = (mkProxyLocation "tachidesk") // {
          enableBasicAuth = true;
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "tachidesk.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = mkProxyLocation "tachidesk";
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
      # MoviePilot container needs an HTTP-only Jellyfin API entry; Jellyfin
      # stays on rock5c (2026-09-04 decision, previously proxied to macmini
      # which is only powered on occasionally). This vhost keeps its stable
      # name so MoviePilot's --add-host continues to point at rock5c, and
      # proxies to the local jellyfin unix socket like the main vhost. The
      # `/Library/SelectableMediaFolders` rewrite is still needed by
      # MoviePilot's media library scan to present the union of
      # media-radarr/media-sonarr folders.
      "jellyfin-api.${config.networking.hostName}.zhyi.xin" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."= /Library/SelectableMediaFolders" = {
          proxyPass = "http://unix:/run/jellyfin/socket";
          extraConfig = "rewrite ^ /Library/MediaFolders break;";
        };
        locations."/" = {
          proxyPass = "http://unix:/run/jellyfin/socket";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };
        accessibleBy = "private";
        noIndex.enable = true;
      };
    };
}
