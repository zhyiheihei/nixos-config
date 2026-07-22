{
  config,
  LT,
  lib,
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

  # This host has less memory than the author's pve-epyc. Keep the existing
  # swap usable so Hydra evaluation cannot force the kernel to kill a VM.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 10;

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  lantian.backup.enable = true;
  lantian.backup.paths = {
    nvme-nixos-colocrossing = {
      snapshotFrom = "/nix/persistent/var/lib/vz/virtiofs";
      snapshotTo = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-colocrossing";
      backupPath = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-colocrossing/virtiofs/nixos-colocrossing/persistent";
    };
    nvme-nixos-home-vm = {
      snapshotFrom = "/nix/persistent/var/lib/vz/virtiofs";
      snapshotTo = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm";
      backupPath = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm/virtiofs/nixos-home-vm/persistent";
    };
    nvme-nixos-logvm = {
      snapshotFrom = "/nix/persistent/var/lib/vz/virtiofs";
      snapshotTo = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-logvm";
      backupPath = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-logvm/virtiofs/nixos-logvm/persistent";
    };
  };

  services.proxmox-ve.bridges = [ "br0" "br-wan" "br-lan" ];
  services.proxmox-ve.ipAddress = LT.this.interconnect.IPv4;

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
    "${LT.hosts.ml-builder.interconnect.IPv4}" = [ "ml-builder.zhyi.cc" ];
    "${LT.hosts."ml-home-vm".interconnect.IPv4}" = [ "ml-home-vm.zhyi.cc" ];
    "${LT.hosts.logvm.interconnect.IPv4}" = [ "logvm.zhyi.cc" ];
  };

  systemd.network.netdevs.br0 = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
  };

  # WAN bridge: unused eth1 NIC → Router VM uplink
  systemd.network.netdevs.br-wan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-wan";
    };
  };

  # LAN bridge: virtual network for VMs behind Router VM
  systemd.network.netdevs.br-lan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-lan";
    };
  };

  systemd.network.networks = {
    "10-pve-uplink" = {
      matchConfig.Name = "eth0";
      networkConfig.Bridge = "br0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    "10-pve-wan" = {
      matchConfig.Name = "eth1";
      networkConfig.Bridge = "br-wan";
      linkConfig.RequiredForOnline = "no";
    };

    br0 = {
      address = [ "${LT.this.interconnect.IPv4}/24" ];
      gateway = [ "192.168.2.2" ];
      matchConfig.Name = "br0";
      networkConfig.IPv6AcceptRA = "yes";
    };

    br-lan = {
      matchConfig.Name = "br-lan";
      address = [ "192.168.0.254/24" ];
      linkConfig.MTUBytes = "9000";
    };
  };
}
