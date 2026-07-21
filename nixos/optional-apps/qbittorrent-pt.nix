{
  pkgs,
  LT,
  config,
  lib,
  utils,
  ...
}:
let
  user = "zhyi";
  group = "users";
in
{
  systemd.services.qbittorrent-pt = {
    description = "qbittorrent BitTorrent client";
    wants = [ "network-online.target" "mnt-storage.mount" ];
    after = [
      "local-fs.target"
      "network-online.target"
      "nss-lookup.target"
      "mnt-storage.mount"
    ];
    wantedBy = [ "multi-user.target" ];

    # The local cleanup job uses the Web API without credentials. Keep remote
    # WebUI authentication enabled while restoring qBittorrent's old localhost
    # behavior expected by that job.
    preStart = ''
      instanceDir=/var/lib/qbittorrent-pt/qBittorrent_pt
      config=$instanceDir/config/qBittorrent.conf
      mkdir -p "$(dirname "$config")"
      touch "$config"
      if ! grep -q '^\[Preferences\]$' "$config"; then
        printf '[Preferences]\n' >> "$config"
      fi
      sed -i '/^WebUILocalHostAuth=/d' "$config"
      sed -i '/^WebUI\\\\LocalHostAuth=/d' "$config"
      sed -i "/^\[Preferences\]$/a WebUI\\\\LocalHostAuth=false" "$config"
    '';

    serviceConfig = LT.serviceHarden // {
      User = user;
      Group = group;
      StateDirectory = "qbittorrent-pt";

      # For PT sites qBit enhanced is unnecessary
      ExecStart = utils.escapeSystemdExecArgs [
        (lib.getExe pkgs.qbittorrent-nox)
        "--profile=/var/lib/qbittorrent-pt"
        "--configuration=pt"
        "--webui-port=${LT.portStr.qBitTorrentPT.WebUI}"
        "--torrenting-port=${builtins.toString (LT.this.wg-zhyi.forwardStart + 1)}"
        "--confirm-legal-notice"
      ];
      TimeoutStopSec = 1800;

      # https://github.com/qbittorrent/qBittorrent/pull/6806#discussion_r121478661
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
  systemd.tmpfiles.settings = {
    qbittorrent = {
      "/var/lib/qbittorrent-pt/qBittorrent/"."d" = {
        mode = "755";
        inherit user group;
      };
      "/var/lib/qbittorrent-pt/qBittorrent/config/"."d" = {
        mode = "755";
        inherit user group;
      };
    };
  };

  lantian.nginxVhosts = {
    "pt.${config.networking.hostName}.zhyi.cc" = {
      locations = {
        "/" = {
          allowCORS = true;
          proxyPass = "http://127.0.0.1:${LT.portStr.qBitTorrentPT.WebUI}";
        };
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "pt.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations = {
        "/" = {
          allowCORS = true;
          proxyPass = "http://127.0.0.1:${LT.portStr.qBitTorrentPT.WebUI}";
        };
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
