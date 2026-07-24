{ lib, ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ./ddns-gcore.nix
    ./dhcp.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/client-components/multicast-dns.nix
    ../../nixos/optional-apps/lancache.nix
    ../../nixos/optional-apps/dae.nix
    ../../nixos/optional-apps/miniupnpd.nix
    ../../nixos/optional-apps/nmea-static-gps-server.nix
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/ncps-client.nix
  ];

  services.miniupnpd = {
    externalInterface = "ppp0";
    internalIPs = [ "br-lan" ];
  };

  lantian.dae = {
    lanInterfaces = [ "br-lan" ];
    intlAction = "proxy";
  };

  services.lancache.environment = {
    LANCACHE_IP = "192.168.0.4";
    DNS_BIND_IP = "192.168.0.4";
    CACHE_ROOT = "/mnt/unreliable-cache/lancache";
    CACHE_DISK_SIZE = "120g";
    MIN_FREE_DISK = "20g";
  };

  services.ncps.cache = {
    storage.local = "/mnt/unreliable-cache/ncps";
    tempPath = "/mnt/unreliable-cache/ncps-tmp";
    maxSize = lib.mkForce "50G";
  };

  systemd.tmpfiles.settings.router-cache = {
    "/mnt/unreliable-cache/lancache/cache"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/mnt/unreliable-cache/lancache/logs"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/mnt/unreliable-cache/ncps"."d" = {
      mode = "0711";
      user = "ncps";
      group = "ncps";
    };
    "/mnt/unreliable-cache/ncps/db"."d" = {
      mode = "0711";
      user = "ncps";
      group = "ncps";
    };
    "/mnt/unreliable-cache/ncps-tmp"."d" = {
      mode = "0711";
      user = "ncps";
      group = "ncps";
    };
  };

  systemd.services = {
    ncps.after = [ "systemd-tmpfiles-resetup.service" ];
    podman-lancache-dns.after = [ "systemd-tmpfiles-resetup.service" ];
    podman-lancache-monolithic.after = [ "systemd-tmpfiles-resetup.service" ];
  };
}
