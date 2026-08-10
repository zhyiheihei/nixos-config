{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/minimal.nix

    ./ddns-gcore.nix
    ./dhcp.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./performance.nix
    ./prometheus.nix
    ./qbittorrent.nix
    ./vaults3.nix
    ./wifi.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/client-components/multicast-dns.nix
    ./v2ray.nix
    ../../nixos/optional-apps/miniupnpd.nix
    ../../nixos/optional-apps/nmea-static-gps-server.nix
    ../../nixos/optional-apps/ncps-client.nix
  ];

  # The R5C hardware module force-replaces boot.supportedFilesystems; mirror
  # its list and add NFS at host level. The kernel config already has
  # CONFIG_NFS_FS=y and nfs-utils supplies mount.nfs.
  boot.supportedFilesystems = lib.mkForce [
    "btrfs"
    "ext4"
    "vfat"
    "nfs"
  ];
  environment.systemPackages = [ pkgs.nfs-utils ];

  # Same QNAP export the other media hosts mount.  Router must stay up as the
  # LAN gateway even when the NAS is down, so keep the mount non-fatal.
  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "noatime"
      "hard"
      "vers=4.1"
      "nconnect=16"
    ];
  };

  # Global wait-online is disabled by minimal networking; wait for the static
  # LAN bridge before attempting the NFS mount, mirroring opi5p's lan0 setup.
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@br-lan.service" ];

  services.miniupnpd = {
    externalInterface = "ppp0";
    internalIPs = [ "br-lan" ];
  };
}
