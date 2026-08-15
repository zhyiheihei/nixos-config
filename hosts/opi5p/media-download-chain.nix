{
  pkgs,
  LT,
  config,
  ...
}:
let
  defaultDownloadPath = "/mnt/storage/downloads";
  qBitTorrentPTSonarrDownloadPath = "/mnt/storage/.downloads-qb-pt";
  qBitTorrentSonarrDownloadPath = "/mnt/storage/.downloads-qb";
  qBitTorrentSeedboxDownloadPath = "/mnt/storage/.downloads-qb-seedbox";
  flexgetAutoDownloadPath = "/mnt/storage/.downloads-auto";
  radarrMediaPath = "/mnt/storage/media-radarr";
  sonarrMediaPath = "/mnt/storage/media-sonarr";
in
{
  imports = [
    ../../nixos/optional-apps/bitmagnet.nix
    ../../nixos/optional-apps/iyuuplus.nix
    ../../nixos/optional-apps/peerbanhelper.nix
    ../../nixos/optional-apps/qbittorrent.nix
    ../../nixos/optional-apps/qbittorrent-pt.nix
    ../../nixos/optional-apps/qbittorrent-seedbox.nix
    ../../nixos/optional-apps/sonarr/jproxy.nix
    ../../nixos/optional-apps/tachidesk.nix

    ../../nixos/optional-cron-jobs/flexget
    ../../nixos/optional-cron-jobs/qbittorrent-pt-cleanup
  ];

  systemd.tmpfiles.settings.storage = {
    "/mnt/storage".d = {
      mode = "755";
      user = "root";
      group = "root";
    };
    "${defaultDownloadPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
    "${flexgetAutoDownloadPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
    "${qBitTorrentPTSonarrDownloadPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
    "${qBitTorrentSonarrDownloadPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
    "${qBitTorrentSeedboxDownloadPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
    "${radarrMediaPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
    "${sonarrMediaPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
  };

  systemd.services.qbittorrent = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig.BindPaths = [
      defaultDownloadPath
      qBitTorrentSonarrDownloadPath
    ];
  };

  systemd.services.qbittorrent-pt = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig.BindPaths = [
      defaultDownloadPath
      flexgetAutoDownloadPath
      qBitTorrentPTSonarrDownloadPath
    ];
  };

  systemd.services.qbittorrent-seedbox = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig.BindPaths = [ qBitTorrentSeedboxDownloadPath ];
  };

  systemd.services.flexget-runner = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig.BindPaths = [
      defaultDownloadPath
      flexgetAutoDownloadPath
    ];
  };

  lantian.qbittorrent-seedbox.downloadPath = qBitTorrentSeedboxDownloadPath;
}
