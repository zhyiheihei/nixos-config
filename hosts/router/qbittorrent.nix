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
    sed -i '/^Session\\GlobalDLSpeedLimit=/d' "$conf"
    sed -i '/^Session\\AsyncIOThreadsCount=/d' "$conf"
    sed -i '/^Session\\DiskCacheSize=/d' "$conf"
    sed -i '/^Session\\DiskCacheTTL=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelistEnabled=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelist=/d' "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DefaultSavePath=${unifiedDownloadPath}/" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\Interface=ppp0" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\InterfaceName=ppp0" "$conf"
    # Bind only ppp0's IPv4 address; the interface also carries two global
    # IPv6 addresses that PTTime rejects as "multi-IP" announces.
    sed -i "/^\[BitTorrent\]$/a Session\\\\InterfaceAddress=0.0.0.0" "$conf"
    # Full broadband throughput requires removing the 10MB/s global download
    # cap that was carried into the migrated runtime config.
    sed -i "/^\[BitTorrent\]$/a Session\\\\GlobalDLSpeedLimit=0" "$conf"
    # qBittorrent defaults to 10 async IO threads and an auto-sized disk
    # cache; on the 4-core R5C router cap both to keep torrent IO from
    # starving NAT/softirq work (measured 2026-08-12: load 9-13 -> ~4.6,
    # WAN rx_missed 0).  Keys verified in qbittorrent release-5.2.3
    # sessionimpl.cpp.
    sed -i "/^\[BitTorrent\]$/a Session\\\\AsyncIOThreadsCount=4" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheSize=256" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheTTL=60" "$conf"
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
