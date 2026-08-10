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

  # Notes is a bindfs view of the Syncthing-managed storage, matching the
  # author's client Documents layout. The Notes repo stays independent from
  # this repository.
  fileSystems."/home/zhyi/Documents/Notes" = lib.mkForce {
    device = "/nix/persistent/media/Notes";
    fsType = "fuse.bindfs";
    options = LT.constants.bindfsMountOptions;
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
