{
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ./hardware-configuration.nix
  ];

  # The first-boot DHCP inventory is complete. Keep the board outside the
  # router's dynamic .100-.249 pool and use the same static LAN layout as the
  # other physical infrastructure hosts.
  systemd.network.networks."10-lubancat1-lan" = {
    matchConfig.Name = "eth0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  # Media library + download chain live on the NAS (same direct NFS mount as
  # rock5c uses for MoviePilot); keep the mount available for future services.
  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = [ pkgs.nfs-utils ];
  # noauto + automount：裸 mount 在 NAS 未就绪时失败且不重试，写法
  # 对齐 exam lt-hp-omen（同 opi5p 修复，c72df01ca）。
  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "noauto"
      "hard"
      "vers=4.1"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };

  # automount 触发的 mount 失败不再撞 5 次/10s 限流，NAS 恢复后访问即自愈。
  systemd.units."mnt-storage.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
  };
}
