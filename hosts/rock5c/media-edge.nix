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
  backendHost = {
    bitmagnet = "chromebox";
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
      # 2026-10-17 后端翻到 chromebox:8096（Jellyfin 迁移，本机进程退役）；
      # 迁移前 jellyfin.zhyi.xin 的 443 内网前置 vhost 由 jellyfin-rockchip
      # 模块携带，摘模块后在此重建，保持入口链不变。
      "jellyfin.zhyi.xin" = {
        serverAliases = [ "rk-jellyfin.zhyi.xin" ];
        locations = {
          "/" = {
            proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8096";
            proxyWebsockets = true;
            proxyNoTimeout = true;
          };
          "= /web/".proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8096/web/index.html";
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "jellyfin.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations = {
          "/" = {
            proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8096";
            proxyWebsockets = true;
            proxyNoTimeout = true;
          };
          "= /web/".proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8096/web/index.html";
        };
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
      "jellyfin-api.${config.networking.hostName}.zhyi.xin" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."= /Library/SelectableMediaFolders" = {
          proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8096";
          extraConfig = "rewrite ^ /Library/MediaFolders break;";
        };
        locations."/" = {
          proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8096";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };
        accessibleBy = "private";
        noIndex.enable = true;
      };
    };
}
