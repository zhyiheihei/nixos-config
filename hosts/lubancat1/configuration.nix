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
    networkConfig = {
      IPv6AcceptRA = true;
    };
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };

  networking.networkmanager.enable = lib.mkForce false;


  # Media library + download chain live on the NAS (same direct NFS mount as
  # rock5c uses for MoviePilot); keep the mount available for future services.
  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = [ pkgs.nfs-utils ];
  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "hard"
      "vers=4.1"
      "nconnect=16"
    ];
  };
}
