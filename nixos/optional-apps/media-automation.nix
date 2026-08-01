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
    ./bitmagnet.nix
    ./iyuuplus.nix
    ./peerbanhelper.nix
    ./qbittorrent.nix
    ./qbittorrent-pt.nix
    ./qbittorrent-seedbox.nix
    ./sonarr
    ./tachidesk.nix

    ../optional-cron-jobs/flexget
    ../optional-cron-jobs/qbittorrent-pt-cleanup
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
      inherit (config.services.radarr) user group;
    };
    "${sonarrMediaPath}".d = {
      mode = "755";
      inherit (config.services.sonarr) user group;
    };
  };

  systemd.services.radarr = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig = LT.serviceHarden // {
      BindPaths = [
        radarrMediaPath
        qBitTorrentPTSonarrDownloadPath
        qBitTorrentSonarrDownloadPath
      ];
    };
  };

  systemd.services.sonarr = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig = LT.serviceHarden // {
      BindPaths = [
        sonarrMediaPath
        qBitTorrentPTSonarrDownloadPath
        qBitTorrentSonarrDownloadPath
      ];
    };
  };

  systemd.services.bazarr = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    path = with pkgs; [ mediainfo ];
    serviceConfig = LT.serviceHarden // {
      BindPaths = [
        radarrMediaPath
        sonarrMediaPath
      ];
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
