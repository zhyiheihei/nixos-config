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
    "ensure-printers"
    "immich-machine-learning"
    "immich-server"
    "phpfpm-calibre-cops"
    "podman-archivebox"
    "podman-asf"
    "filecodebox"
    "podman-home-assistant"
    "memos"
    "sun-panel"
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
  targetServices = builtins.filter (name: name != "clamav-fangfrisch") gatedServices;
in
{
  imports = [
    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/filecodebox-nix.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/immich.nix
    ../../nixos/optional-apps/immich-rockchip.nix
    ../../nixos/optional-apps/memos-nix.nix
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/searxng.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/sun-panel-nix.nix
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
    proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    proxyUnit = null;
    storageUnit = "nix.mount";
  };

  # Deploy packages, users, secrets and unit definitions first, but never let
  # a target writer create empty state before the final source freeze/copy.
  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      partOf = [ "ml-home-apps.target" ];
      unitConfig.ConditionPathExists = activationMarker;
    }))
    # The hourly timer can fire before sops-install-secrets writes the calendar
    # sync script on a fresh boot; make the run wait for the secret explicitly.
    {
      radicale-calendar-sync = {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
      };
    }
  ];
  systemd.sockets.cups.unitConfig.ConditionPathExists = activationMarker;
  systemd.targets.ml-home-apps = {
    description = "Migrated ml-home-vm application and storage services";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") targetServices;
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
