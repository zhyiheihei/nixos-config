{
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/ncps-client.nix
    ./hardware-configuration.nix
  ];

  lantian.backup.enable = true;

  systemd.network.networks."10-lubancat1-lan" = {
    matchConfig.Name = "eth0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = [ pkgs.nfs-utils ];

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

  systemd.units."mnt-storage.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
  };
}
