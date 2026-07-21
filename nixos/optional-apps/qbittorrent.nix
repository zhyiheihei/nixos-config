{
  pkgs,
  LT,
  config,
  ...
}:
{
  services.qbittorrent = {
    enable = true;
    package = pkgs.qbittorrent-enhanced-nox;
    user = "zhyi";
    group = "users";
    profileDir = "/var/lib/qbittorrent";
    webuiPort = LT.port.qBitTorrent.WebUI;
    torrentingPort = LT.this.wg-zhyi.forwardStart;
    extraArgs = [
      "--confirm-legal-notice"
    ];
  };

  systemd.services.qbittorrent.serviceConfig = {
    Restart = "always";
    RestartSec = "5";
    UMask = "0002";
    LimitNOFILE = 1048576;
    IOSchedulingClass = "idle";
    IOSchedulingPriority = "7";
  };

  systemd.services.qbittorrent.wants = [ "remote-fs.target" ];
  systemd.services.qbittorrent.after = [ "remote-fs.target" ];
  systemd.services.qbittorrent.preStart = ''
    downloadPath=/mnt/storage/.downloads-qb
    config=/var/lib/qbittorrent/qBittorrent/config/qBittorrent.conf
    mkdir -p "$(dirname "$config")" "$downloadPath"
    touch "$config"
    if ! grep -q '^\[Preferences\]$' "$config"; then
      printf '[Preferences]\n' >> "$config"
    fi
    sed -i '/^Downloads\\SavePath=/d' "$config"
    sed -i "/^\[Preferences\]$/a Downloads\\SavePath=$downloadPath/" "$config"
  '';

  lantian.nginxVhosts = {
    "bt.${config.networking.hostName}.zhyi.cc" = {
      locations = {
        "/" = {
          allowCORS = true;
          proxyPass = "http://127.0.0.1:${LT.portStr.qBitTorrent.WebUI}";
        };
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "bt.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations = {
        "/" = {
          allowCORS = true;
          proxyPass = "http://127.0.0.1:${LT.portStr.qBitTorrent.WebUI}";
        };
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
