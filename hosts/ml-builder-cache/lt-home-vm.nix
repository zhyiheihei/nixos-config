{
  inputs,
  config,
  ...
}:
{
  imports = [
    ../../nixos/client-components/cups.nix
    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/archiveteam.nix
    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/axonhub.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/clawemail.nix
    ../../nixos/optional-apps/epic-awesome-gamer
    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/glauth.nix
    ../../nixos/optional-apps/handbrake-server.nix
    ../../nixos/optional-apps/immich.nix
    ../../nixos/optional-apps/iyuuplus.nix
    ../../nixos/optional-apps/llama-cpp.nix
    ../../nixos/optional-apps/metapi.nix
    ../../nixos/optional-apps/n8n
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/open-webui
    ../../nixos/optional-apps/searxng.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/tachidesk.nix
    ../../nixos/optional-apps/uni-api.nix
    ../../nixos/optional-apps/vlmcsd.nix
    ../../nixos/optional-apps/webdav.nix

    ../../nixos/optional-cron-jobs/qbittorrent-pt-cleanup
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix

    "${inputs.secrets}/nixos-hidden-module/851e5310ebca4e5c"
  ];

  fileSystems."/mnt/storage" = {
    device = "192.168.2.93:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "clientaddr=192.168.2.135"
      "hard"
      "vers=4.1"
      "nconnect=16"
    ];
  };

  services.calibre-cops.libraryPath = "/mnt/storage/Calibre Library";

  services.printing = {
    browsing = true;
    defaultShared = true;
    listenAddresses = [
      "127.0.0.1:631"
      "192.168.2.135:631"
    ];
    allowFrom = [ "all" ];
  };

  lantian.immich.storage = "/mnt/storage/immich";
  lantian.syncthing.storage = "/mnt/storage/media";
  lantian.archivebox.storage = "/mnt/storage/archivebox";

  systemd.services.radicale-calendar-sync.serviceConfig = {
    AmbientCapabilities = [ "CAP_DAC_OVERRIDE" ];
    CapabilityBoundingSet = [ "CAP_DAC_OVERRIDE" ];
  };

  systemd.tmpfiles.settings.lt-home-vm-storage = {
    "/mnt/storage".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
  };
}
