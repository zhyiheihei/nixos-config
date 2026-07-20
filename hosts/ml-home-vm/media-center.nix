{
  pkgs,
  lib,
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
  cloudMusicPath = "/mnt/storage/media/CloudMusic";
  cloudMusicArchivePath = "/mnt/storage/media/CloudMusicArchive";
  radarrMediaPath = "/mnt/storage/media-radarr";
  sonarrMediaPath = "/mnt/storage/media-sonarr";
in
{
  imports = [
    ../../nixos/client-components/hidpi.nix
    ../../nixos/client-components/xorg.nix

    ../../nixos/optional-apps/bitmagnet.nix
    ../../nixos/optional-apps/jellyfin.nix
    ../../nixos/optional-apps/peerbanhelper.nix
    ../../nixos/optional-apps/qbittorrent.nix
    ../../nixos/optional-apps/qbittorrent-pt.nix
    ../../nixos/optional-apps/qbittorrent-seedbox.nix
    ../../nixos/optional-apps/sonarr

    ../../nixos/optional-cron-jobs/flexget
  ];

  services.xserver.enable = lib.mkForce false;

  systemd.tmpfiles.settings.storage = {
    "/mnt/storage".d = {
      mode = "755";
      user = "root";
      group = "root";
    };
    "${defaultDownloadPath}".d = {
      mode = "755";
      user = "lantian";
      group = "users";
    };
    "${flexgetAutoDownloadPath}".d = {
      mode = "755";
      user = "lantian";
      group = "users";
    };
    "${qBitTorrentPTSonarrDownloadPath}".d = {
      mode = "755";
      user = "lantian";
      group = "users";
    };
    "${qBitTorrentSonarrDownloadPath}".d = {
      mode = "755";
      user = "lantian";
      group = "users";
    };
    "${qBitTorrentSeedboxDownloadPath}".d = {
      mode = "755";
      user = "lantian";
      group = "users";
    };
    "${cloudMusicPath}".d = {
      mode = "755";
      inherit (config.services.syncthing) user group;
    };
    "${cloudMusicArchivePath}".d = {
      mode = "755";
      inherit (config.services.syncthing) user group;
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

  systemd.services.podman-archivebox = {
    environment = {
      HTTP_PROXY = "http://openclash.zhyi.cc:7892";
      HTTPS_PROXY = "http://openclash.zhyi.cc:7892";
      NO_PROXY = "localhost,127.0.0.1,::1,.zhyi.cc,.zhyi.xin,192.168.0.0/16";
    };
  };

  systemd.services.podman-handbrake = {
    environment = {
      HTTP_PROXY = "http://openclash.zhyi.cc:7892";
      HTTPS_PROXY = "http://openclash.zhyi.cc:7892";
      NO_PROXY = "localhost,127.0.0.1,::1,.zhyi.cc,.zhyi.xin,192.168.0.0/16";
    };
  };
}
