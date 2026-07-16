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
    ../../nixos/optional-apps/ncps-client.nix

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

  lantian.backup.enable = true;
  lantian.backup.paths = {
    nvme-nixos-home-vm = {
      snapshotFrom = "/nix/persistent/var/lib/vz/virtiofs";
      snapshotTo = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm";
      backupPath = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm/virtiofs/nixos-home-vm/persistent";
    };
  };

  services.proxmox-ve.bridges = [ "br0" ];
  services.proxmox-ve.ipAddress = LT.this.interconnect.IPv4;

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
    "${LT.hosts.colocrossing.interconnect.IPv4}" = [
      "attic.zhyi.xin"
      "colocrossing.zhyi.cc"
      "hydra.zhyi.cc"
    ];
    "${LT.hosts.ml-builder.interconnect.IPv4}" = [ "ml-builder.zhyi.cc" ];
    "${LT.hosts."ml-home-vm".interconnect.IPv4}" = [ "ml-home-vm.zhyi.cc" ];
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
