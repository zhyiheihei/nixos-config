{ LT, ... }:
{
  imports = [
    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/filecodebox-nix.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/ignis.nix
    ../../nixos/optional-apps/immich.nix
    ../../nixos/optional-apps/immich-rockchip.nix
    ../../nixos/optional-apps/memos-nix.nix
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/resilio-sync.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/sun-panel-nix.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/wallos.nix
    ../../nixos/optional-apps/webdav.nix
    ../../nixos/client-components/cups.nix
    ../../nixos/client-components/multicast-dns.nix
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix

    ./home-storage-shares.nix
    ./edge-vhosts.nix
  ];

  # NAS payloads remain on QNAP. Databases, container state and the NCPS
  # cache use the local NVMe-backed persistent filesystem.
  lantian.archivebox.storage = "/mnt/storage/archivebox";
  lantian.immich.storage = "/mnt/storage/immich";
  lantian.syncthing.storage = "/mnt/storage/media";
  services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";

  # Resilio Sync migrated from the QNAP NAS (2026-08). Identity and config
  # stay in the local /var/lib/resilio-sync; the synced folders are served
  # from the NFS share (bind-mounted at /sync and /downloads by the module).
  lantian.resilioSync = {
    dataDir = "/mnt/storage/resilio/data";
    downloadsDir = "/mnt/storage/resilio/downloads";
  };

  # Ignis vault is the knowledge-chain Notes folder (Syncthing home copy on the
  # NFS share); the module defaults already point at it, just enable it here.
  lantian.ignis.enable = true;

  # Wallos subscription tracker: private home service, SQLite state on the local
  # NVMe-backed persistent storage alongside the other container workloads.
  lantian.wallos.enable = true;

  # The hourly timer can fire before sops-install-secrets writes the calendar
  # sync script on a fresh boot; make the run wait for the secret explicitly.
  systemd.services.radicale-calendar-sync = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  # Manual import drop folder for the Immich external library. It lives on the
  # NFS-backed /mnt/storage so both the immich service and zhyi (via SMB/SSH)
  # can reach it without crossing the immich-only /mnt/storage/immich root.
  systemd.tmpfiles.settings.immich-import."/mnt/storage/immich-import"."d" = {
    mode = "0775";
    user = "immich";
    group = "users";
  };

  # FlClash MKCOLs /FlClash/ before every WebDAV backup and webdav_client
  # treats MKCOL 405 as success, so pre-provision the writable target dir.
  systemd.tmpfiles.settings.flclash."/mnt/storage/FlClash"."d" = {
    mode = "0775";
    user = "zhyi";
    group = "users";
  };
}
