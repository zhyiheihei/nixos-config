{
  config,
  ...
}:
{
  imports = [
    ../../nixos/pve.nix

    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  services.proxmox-ve.bridges = [ "br0" ];
  services.proxmox-ve.ipAddress = "192.168.2.10";

  networking.hosts = {
    "192.168.2.10" = [ config.networking.hostName ];
  };

  systemd.network.netdevs.br0 = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
  };

  systemd.network.networks = {
    "10-pve-uplink" = {
      matchConfig.Name = "eth0";
      networkConfig.Bridge = "br0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    br0 = {
      address = [ "192.168.2.10/24" ];
      gateway = [ "192.168.2.2" ];
      matchConfig.Name = "br0";
      networkConfig.IPv6AcceptRA = "yes";
    };
  };
}
