{
  config,
  lib,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/qbittorrent-router/ready";
  user = "zhyi";
  group = "users";
  # MoviePilot skips hidden paths during transfer, so the unified download
  # root must be a plain directory instead of the old ".downloads-*" names.
  unifiedDownloadPath = "/mnt/storage/downloads";
in
{
  imports = [
    ../../nixos/optional-apps/qbittorrent-unified.nix
    # Author-style layout: qBittorrent and its WebUI vhosts live on the same
    # host, so router serves bt/pt/seedbox.router.zhyi.cc directly.
    ../../nixos/common-apps/nginx/nginx.nix
    ../../nixos/common-apps/nginx/vhost-options/default.nix
  ];

  lantian.qbittorrent-unified = {
    enable = true;
    torrentingPort = 31220;
    networkInterface = "ppp0";
    authSubnetWhitelist = [
      "192.168.0.62"
      "192.168.0.64"
    ];
  };

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

  systemd.services.qbittorrent = {
    unitConfig.ConditionPathExists = activationMarker;
    partOf = [ "qbittorrent-router.target" ];
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig.BindPaths = [ unifiedDownloadPath ];
  };

  systemd.targets.qbittorrent-router = {
    description = "Router qBittorrent downloaders";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = [ "qbittorrent.service" ];
    after = [ "mnt-storage.mount" ];
  };
}
