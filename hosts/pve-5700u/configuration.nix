{
  config,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/hardware/lvm.nix
    ../../nixos/hardware/smart.nix
    ../../nixos/pve.nix

    # Match the upstream pve-epyc role: Hydra runs on the PVE host.
    ../../nixos/optional-apps/hydra

    ./enable-smart.nix
    ./hardware-configuration.nix
  ];

  boot.kernelParams = [
    "amd_pstate=active"
    "amd_pstate.shared_mem=1"
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  services.proxmox-ve.bridges = [ "br0" ];
  services.proxmox-ve.ipAddress = LT.this.interconnect.IPv4;

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
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
      address = [ "${LT.this.interconnect.IPv4}/24" ];
      gateway = [ "192.168.2.2" ];
      matchConfig.Name = "br0";
      networkConfig.IPv6AcceptRA = "yes";
    };
  };
}
