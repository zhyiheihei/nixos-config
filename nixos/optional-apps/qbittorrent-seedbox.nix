{
  pkgs,
  LT,
  config,
  lib,
  utils,
  ...
}:
let
  user = "lantian";
  group = "users";
  downloadPath = "/mnt/storage/.downloads-qb-seedbox";
in
{
  systemd.services.qbittorrent-seedbox = {
    description = "qBittorrent seedbox client";
    wants = [ "network-online.target" ];
    after = [
      "local-fs.target"
      "network-online.target"
      "nss-lookup.target"
    ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      instanceDir=/var/lib/qbittorrent-seedbox/qBittorrent_seedbox
      config=$instanceDir/config/qBittorrent.conf
      mkdir -p "$(dirname "$config")"
      touch "$config"
      if ! grep -q '^\[Preferences\]$' "$config"; then
        printf '[Preferences]\n' >> "$config"
      fi
      sed -i '/^Downloads\\SavePath=/d' "$config"
      sed -i '/^WebUI\\LocalHostAuth=/d' "$config"
      sed -i "/^\[Preferences\]$/a Downloads\\SavePath=$downloadPath/" "$config"
      sed -i "/^\[Preferences\]$/a WebUI\\LocalHostAuth=true" "$config"
    '';

    serviceConfig = LT.serviceHarden // {
      User = user;
      Group = group;
      StateDirectory = "qbittorrent-seedbox";

      ExecStart = utils.escapeSystemdExecArgs [
        (lib.getExe pkgs.qbittorrent-nox)
        "--profile=/var/lib/qbittorrent-seedbox"
        "--configuration=seedbox"
        "--webui-port=${LT.portStr.qBitTorrentSeedbox.WebUI}"
        "--torrenting-port=${builtins.toString (LT.this.wg-lantian.forwardStart + 2)}"
        "--confirm-legal-notice"
      ];
      TimeoutStopSec = 1800;
      PrivateTmp = false;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];

      Restart = "always";
      RestartSec = "5";
      UMask = "0002";
      LimitNOFILE = 1048576;
      IOSchedulingClass = "idle";
      IOSchedulingPriority = "7";
    };
  };

  systemd.tmpfiles.settings.qbittorrent-seedbox = {
    "/var/lib/qbittorrent-seedbox/qBittorrent_seedbox/config".d = {
      mode = "755";
      inherit user group;
    };
  };

  lantian.nginxVhosts = {
    "seedbox.${config.networking.hostName}.zhyi.cc" = {
      locations."/" = {
        allowCORS = true;
        proxyPass = "http://127.0.0.1:${LT.portStr.qBitTorrentSeedbox.WebUI}";
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "seedbox.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations."/" = {
        allowCORS = true;
        proxyPass = "http://127.0.0.1:${LT.portStr.qBitTorrentSeedbox.WebUI}";
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
