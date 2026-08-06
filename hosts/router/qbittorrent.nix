{
  config,
  lib,
  LT,
  pkgs,
  utils,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/qbittorrent-router/ready";
  user = "zhyi";
  group = "users";
  defaultDownloadPath = "/mnt/storage/downloads";
  flexgetAutoDownloadPath = "/mnt/storage/.downloads-auto";
  qBitTorrentSonarrDownloadPath = "/mnt/storage/.downloads-qb";
  qBitTorrentPTSonarrDownloadPath = "/mnt/storage/.downloads-qb-pt";
  qBitTorrentSeedboxDownloadPath = "/mnt/storage/.downloads-qb-seedbox";
  qbitServices = [
    "qbittorrent"
    "qbittorrent-pt"
    "qbittorrent-seedbox"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/qbittorrent.nix
    ../../nixos/optional-apps/qbittorrent-pt.nix
    ../../nixos/optional-apps/qbittorrent-seedbox.nix
    # Author-style layout: qBittorrent and its WebUI vhosts live on the same
    # host, so router serves bt/pt/seedbox.router.zhyi.cc directly.
    ../../nixos/common-apps/nginx/nginx.nix
    ../../nixos/common-apps/nginx/vhost-options/default.nix
  ];

  services.qbittorrent = {
    enable = true;
    package = pkgs.qbittorrent-enhanced-nox;
    inherit user group;
    profileDir = "/var/lib/qbittorrent";
    webuiPort = LT.port.qBitTorrent.WebUI;
    torrentingPort = lib.mkForce 31220;
    extraArgs = [ "--confirm-legal-notice" ];
  };

  systemd.tmpfiles.settings.qbittorrent-router = {
    "/mnt/storage".d = {
      mode = "755";
      user = "root";
      group = "root";
    };
    "${defaultDownloadPath}".d = {
      mode = "755";
      inherit user group;
    };
    "${flexgetAutoDownloadPath}".d = {
      mode = "755";
      inherit user group;
    };
    "${qBitTorrentSonarrDownloadPath}".d = {
      mode = "755";
      inherit user group;
    };
    "${qBitTorrentPTSonarrDownloadPath}".d = {
      mode = "755";
      inherit user group;
    };
    "${qBitTorrentSeedboxDownloadPath}".d = {
      mode = "755";
      inherit user group;
    };
    "/nix/persistent/var/lib/qbittorrent-router".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs qbitServices (_: {
      unitConfig.ConditionPathExists = activationMarker;
      partOf = [ "qbittorrent-router.target" ];
      after = [ "mnt-storage.mount" ];
      requires = [ "mnt-storage.mount" ];
    }))
    {
      qbittorrent.serviceConfig.BindPaths = [
        defaultDownloadPath
        qBitTorrentSonarrDownloadPath
      ];
      qbittorrent-pt = {
        serviceConfig = {
          ExecStart = lib.mkForce (utils.escapeSystemdExecArgs [
            (lib.getExe pkgs.qbittorrent-nox)
            "--profile=/var/lib/qbittorrent-pt"
            "--webui-port=${LT.portStr.qBitTorrentPT.WebUI}"
            "--torrenting-port=31221"
            "--confirm-legal-notice"
          ]);
          BindPaths = [
            defaultDownloadPath
            flexgetAutoDownloadPath
            qBitTorrentPTSonarrDownloadPath
          ];
        };
      };
      qbittorrent-seedbox = {
        serviceConfig = {
          ExecStart = lib.mkForce (utils.escapeSystemdExecArgs [
            (lib.getExe pkgs.qbittorrent-nox)
            "--profile=/var/lib/qbittorrent-seedbox"
            "--webui-port=${LT.portStr.qBitTorrentSeedbox.WebUI}"
            "--torrenting-port=31222"
            "--confirm-legal-notice"
          ]);
          BindPaths = [ qBitTorrentSeedboxDownloadPath ];
        };
      };
    }
  ];

  systemd.targets.qbittorrent-router = {
    description = "Router qBittorrent downloaders";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") qbitServices;
    after = [ "mnt-storage.mount" ];
  };

  lantian.qbittorrent-seedbox.downloadPath = qBitTorrentSeedboxDownloadPath;
}
