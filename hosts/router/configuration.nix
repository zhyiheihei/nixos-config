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
    ./flowtable.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./performance.nix
    ./prometheus.nix
    ./qbittorrent.nix
    ./quality-monitoring.nix
    ./vaults3.nix
    ./wifi.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/client-components/multicast-dns.nix
    ./v2ray.nix
    ../../nixos/optional-apps/miniupnpd.nix
    ../../nixos/optional-apps/nmea-static-gps-server.nix
    ../../nixos/optional-apps/ncps-client.nix
  ];

  # 家内 DNS：searx.tencent.zhyi.cc 解析到 tencent 的 LTNET 地址。
  # tencent 的 searx vhost 是 private（作者布局），公网直连会被 444 掐断
  # （浏览器报"建立安全连接失败"）；走 LTNET 后 router NAT 以保留地址
  # 出站、private 规则放行。services.coredns.config 是 lines 类型，
  # 主机层追加 hosts 区即可，不动公共模块。
  services.coredns.config = ''
    searx.tencent.zhyi.cc {
      hosts {
        198.18.0.128 searx.tencent.zhyi.cc
        fallthrough
      }
    }
  '';

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
