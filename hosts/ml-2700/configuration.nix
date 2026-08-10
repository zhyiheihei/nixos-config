{
  config,
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/client.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/syncthing
  ];

  lantian.syncthing.storage = "/nix/persistent/media";

  # Notes stays a plain directory; give the syncthing service write access
  # through the zhyi group instead of adding custom bind mounts.
  users.groups.zhyi.members = [ "syncthing" ];

  systemd.services.syncthing.serviceConfig = {
    ReadWritePaths = lib.mkForce [
      "/run/syncthing-files"
      "/home/zhyi/Documents/Notes"
    ];
    # PrivateUsers remaps uid/gid and breaks file/ACL access to /home.
    PrivateUsers = lib.mkForce false;
  };

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  systemd.network.networks.eth1 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    matchConfig.Name = "eth1";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };
}
