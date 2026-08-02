{
  config,
  lib,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/ml-home-migration/opi5p-ready";
  gatedServices = [
    "clamav-daemon"
    "clamav-fangfrisch"
    "clamav-freshclam"
    "cups"
    "immich-machine-learning"
    "immich-server"
    "ncps"
    "phpfpm-calibre-cops"
    "podman-archivebox"
    "podman-asf"
    "podman-filecodebox"
    "podman-freshrss"
    "podman-home-assistant"
    "podman-linkwarden"
    "podman-memos"
    "podman-sun-panel"
    "podman-sun-panel-helper"
    "redis-immich"
    "redis-searx"
    "radicale-calendar-sync"
    "rsgain-cloudmusic"
    "searx-init"
    "syncthing"
    "uwsgi"
    "webdav"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/filecodebox.nix
    ../../nixos/optional-apps/freshrss.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/immich.nix
    ../../nixos/optional-apps/linkwarden.nix
    ../../nixos/optional-apps/memos.nix
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/searxng.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/sun-panel.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/webdav.nix
    ../../nixos/client-components/cups.nix
    ../../nixos/client-components/multicast-dns.nix
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix

    ./home-storage-shares.nix
    ./vaults3.nix
  ];

  # NAS payloads remain on QNAP. Databases, container state and the NCPS
  # cache use the local NVMe-backed persistent filesystem.
  lantian.archivebox.storage = "/mnt/storage/archivebox";
  lantian.immich.storage = "/mnt/storage/immich";
  lantian.syncthing.storage = "/mnt/storage/media";
  services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";
  lantian.ncps = {
    dataPath = "/nix/persistent/var/cache/ncps";
    tempPath = "/nix/persistent/var/cache/ncps-tmp";
    proxy = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    proxyUnit = null;
    storageUnit = "nix.mount";
  };

  # Deploy packages, users, secrets and unit definitions first, but never let
  # a target writer create empty state before the final source freeze/copy.
  systemd.services = lib.genAttrs gatedServices (_: {
    partOf = [ "ml-home-apps.target" ];
    unitConfig.ConditionPathExists = activationMarker;
  });
  systemd.targets.ml-home-apps = {
    description = "Migrated ml-home-vm application and storage services";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices;
    after = [
      "mnt-storage.mount"
      "postgresql.service"
      "mysql.service"
    ];
  };

  systemd.tmpfiles.settings.ml-home-migration."/nix/persistent/var/lib/ml-home-migration".d = {
    mode = "0700";
    user = "root";
    group = "root";
  };
}
