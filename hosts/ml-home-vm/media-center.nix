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
  flexgetAutoDownloadPath = "/mnt/storage/.downloads-auto";
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
    ../../nixos/optional-apps/sonarr

    ../../nixos/optional-cron-jobs/flexget
  ];

  services.xserver.enable = lib.mkForce false;

  systemd.services.ml-home-vm-storage-setup = {
    description = "Create ml-home-vm storage directories after mounting the NAS";
    wantedBy = [ "multi-user.target" ];
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    before = [
      "bazarr.service"
      "podman-archivebox.service"
      "podman-handbrake.service"
      "qbittorrent.service"
      "qbittorrent-pt.service"
      "radarr.service"
      "sonarr.service"
      "syncthing.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' pkgs.systemd "systemd-tmpfiles"} --create --prefix=/mnt/storage";
    };
  };

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
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
    serviceConfig = LT.serviceHarden // {
      BindPaths = [
        radarrMediaPath
        qBitTorrentPTSonarrDownloadPath
        qBitTorrentSonarrDownloadPath
      ];
    };
  };

  systemd.services.sonarr = {
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
    serviceConfig = LT.serviceHarden // {
      BindPaths = [
        sonarrMediaPath
        qBitTorrentPTSonarrDownloadPath
        qBitTorrentSonarrDownloadPath
      ];
    };
  };

  systemd.services.bazarr = {
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
    path = with pkgs; [ mediainfo ];
    serviceConfig = LT.serviceHarden // {
      BindPaths = [
        radarrMediaPath
        sonarrMediaPath
      ];
    };
  };

  systemd.services.qbittorrent = {
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
    serviceConfig.BindPaths = [
      defaultDownloadPath
      qBitTorrentSonarrDownloadPath
    ];
  };

  systemd.services.qbittorrent-pt = {
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
    serviceConfig.BindPaths = [
      defaultDownloadPath
      flexgetAutoDownloadPath
      qBitTorrentPTSonarrDownloadPath
    ];
  };

  systemd.services.syncthing = {
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
  };

  systemd.services.podman-archivebox = {
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
    environment = {
      HTTP_PROXY = "http://openclash.zhyi.cc:7892";
      HTTPS_PROXY = "http://openclash.zhyi.cc:7892";
      NO_PROXY = "localhost,127.0.0.1,::1,.zhyi.cc,.zhyi.xin,192.168.0.0/16";
    };
  };

  systemd.services.podman-handbrake = {
    after = [ "ml-home-vm-storage-setup.service" ];
    requires = [ "ml-home-vm-storage-setup.service" ];
    environment = {
      HTTP_PROXY = "http://openclash.zhyi.cc:7892";
      HTTPS_PROXY = "http://openclash.zhyi.cc:7892";
      NO_PROXY = "localhost,127.0.0.1,::1,.zhyi.cc,.zhyi.xin,192.168.0.0/16";
    };
  };
}
