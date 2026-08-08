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
  authSubnetWhitelist = "192.168.0.62,192.168.0.64";
  # One download root for every qBittorrent client after the merge.  The old
  # hidden PT path is renamed to this and the seedbox data is moved into it,
  # so MoviePilot can match a single save path and transfer into the libraries.
  unifiedDownloadPath = "/mnt/storage/.downloads";
  # Single qBittorrent instance after the downloader merge.  PT and seedbox
  # units are kept defined by their modules but disabled below; torrent data
  # is already on the shared NFS paths, so one client can own all of them.
  qbitServices = [ "qbittorrent" ];
  qbitPreStart = instance: ''
    conf=/var/lib/${instance}/qBittorrent/config/qBittorrent.conf
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    if ! grep -q '^\[Preferences\]$' "$conf"; then
      printf '[Preferences]\n' >> "$conf"
    fi
    sed -i '/^WebUI\\AuthSubnetWhitelistEnabled=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelist=/d' "$conf"
    sed -i '/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelistEnabled=true' "$conf"
    sed -i '/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelist=${authSubnetWhitelist}' "$conf"
  '';
in
{
  imports = [
    ../../nixos/optional-apps/qbittorrent.nix
    ../../nixos/optional-apps/qbittorrent-pt.nix
    ../../nixos/optional-apps/qbittorrent-seedbox.nix
    ../../nixos/optional-cron-jobs/qbittorrent-pt-cleanup
    # Author-style layout: qBittorrent and its WebUI vhosts live on the same
    # host, so router serves bt/pt/seedbox.router.zhyi.cc directly.
    ../../nixos/common-apps/nginx/nginx.nix
    ../../nixos/common-apps/nginx/vhost-options/default.nix
  ];

  # This router's qBittorrent build does not treat IPv4 127.0.0.1 as loopback
  # for the WebUI auth bypass, while [::1] works. Keep the author-style vhost
  # structure and only change the host-level backend address.
  lantian.nginxVhosts = {
    "bt.${config.networking.hostName}.zhyi.cc".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    "bt.localhost".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    # After the merge these names alias the same single client so existing
    # bookmarks and automation entries keep working.
    "pt.${config.networking.hostName}.zhyi.cc".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    "pt.localhost".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    "seedbox.${config.networking.hostName}.zhyi.cc".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    "seedbox.localhost".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
  };

  services.qbittorrent.torrentingPort = lib.mkForce 31220;

  systemd.tmpfiles.settings.qbittorrent-router = {
    "/mnt/storage".d = {
      mode = "755";
      user = "root";
      group = "root";
    };
    "${unifiedDownloadPath}".d = {
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
      qbittorrent.preStart = lib.mkAfter (qbitPreStart "qbittorrent");
      qbittorrent.serviceConfig.BindPaths = [
        unifiedDownloadPath
      ];
      # Old multi-instance units stay defined in their modules for rollback,
      # but are no longer part of the active single-client stack.
      qbittorrent-pt.enable = lib.mkForce false;
      qbittorrent-seedbox.enable = lib.mkForce false;
      qbittorrent-pt-cleanup.enable = lib.mkForce false;
    }
  ];

  systemd.targets.qbittorrent-router = {
    description = "Router qBittorrent downloaders";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") qbitServices;
    after = [ "mnt-storage.mount" ];
  };

  systemd.timers.qbittorrent-pt-cleanup.enable = lib.mkForce false;

  lantian.qbittorrent-seedbox.downloadPath = unifiedDownloadPath;
}
