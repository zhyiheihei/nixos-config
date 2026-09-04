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
    "peerbanhelper"
    "bitmagnet"
    "iyuu"
  ];
  qbitPorts = {
    bt = LT.port.qBitTorrent.WebUI;
    pt = LT.port.qBitTorrentPT.WebUI;
    seedbox = LT.port.qBitTorrentSeedbox.WebUI;
  };
  # 边缘反代后端所在主机（bitmagnet/peerbanhelper/tachidesk 在 dragon-q8b，
  # 其余在 opi5p）。
  backendHost = {
    bitmagnet = "dragon-q8b";
    peerbanhelper = "dragon-q8b";
    tachidesk = "dragon-q8b";
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
      # tachidesk 后端在 dragon-q8b，边缘直连其机器域。
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
      # MoviePilot 专用 HTTP-only Jellyfin API 入口（--add-host 指名依赖
      # 此稳定域名；rewrite 供其媒体库扫描聚合 radarr/sonarr 目录）。
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
