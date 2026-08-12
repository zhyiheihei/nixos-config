{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/qbittorrent-router/ready";
  authSubnetWhitelist = "192.168.0.62,192.168.0.64";
  unifiedDownloadPath = "/mnt/storage/downloads";
  qbitPreStart = ''
    conf=/var/lib/qbittorrent/qBittorrent/config/qBittorrent.conf
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    if ! grep -q '^\[BitTorrent\]$' "$conf"; then
      printf '[BitTorrent]\n' >> "$conf"
    fi
    if ! grep -q '^\[Preferences\]$' "$conf"; then
      printf '[Preferences]\n' >> "$conf"
    fi
    sed -i '/^Session\\DefaultSavePath=/d' "$conf"
    sed -i '/^Session\\Interface=/d' "$conf"
    sed -i '/^Session\\InterfaceName=/d' "$conf"
    sed -i '/^Session\\InterfaceAddress=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelistEnabled=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelist=/d' "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DefaultSavePath=${unifiedDownloadPath}/" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\Interface=ppp0" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\InterfaceName=ppp0" "$conf"
    sed -i '/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelistEnabled=true' "$conf"
    sed -i "/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelist=${authSubnetWhitelist}" "$conf"
  '';
in
{
  imports = [
    ./qbittorrent-directory.nix
    ../../nixos/optional-apps/qbittorrent.nix
    # Author-style layout: qBittorrent and its WebUI vhosts live on the same
    # host, so router serves bt/pt/seedbox.router.zhyi.cc directly.
    ../../nixos/common-apps/nginx/nginx.nix
    ../../nixos/common-apps/nginx/vhost-options/default.nix
  ];

  # Public module stays upstream-aligned; router only adds host-specific
  # extension keys: official client, fixed port, one WAN interface, unified
  # save path, and LAN auth bypass.
  services.qbittorrent = {
    package = lib.mkForce pkgs.qbittorrent-nox;
    torrentingPort = lib.mkForce 31220;
  };

  # This router's qBittorrent build does not treat IPv4 127.0.0.1 as loopback
  # for the WebUI auth bypass, while [::1] works. Keep the author-style vhost
  # structure and only change the host-level backend address.
  lantian.nginxVhosts = {
    "bt.${config.networking.hostName}.zhyi.cc".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    "bt.localhost".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
  };

  systemd.services.qbittorrent = {
    unitConfig.ConditionPathExists = activationMarker;
    preStart = lib.mkAfter qbitPreStart;
  };
}
