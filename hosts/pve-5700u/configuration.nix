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
    ./ml-home-x86.nix
  ];

  boot.kernelParams = [
    "amd_pstate=active"
    "amd_pstate.shared_mem=1"
  ];

  # This host has less memory than the author's pve-epyc. Keep the existing
  # swap usable so Hydra evaluation cannot force the kernel to kill a VM.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 10;

  # Hydra and two resident VMs share this host. Keep fallback builds at one
  # derivation at a time; unlimited cores avoid wasting the local CPU while
  # the single job stays inside its memory budget.
  nix.settings.max-jobs = lib.mkForce 1;

  # Do not let an upstream merge silently turn the VM host back into a
  # high-concurrency builder. ml-builder is the only node allowed to do that.
  assertions = [
    {
      assertion = LT.this.nixBuilder.maxJobs == 1 && config.nix.settings.max-jobs == 1;
      message = "pve-5700u must remain a single-job fallback builder; use ml-builder for parallel builds";
    }
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  lantian.backup.enable = true;
  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; the VirtioFS
  # backup of the former home VM goes to the migrated backup server too.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";
  # The active Btrfs swapfile prevents snapshotting the whole /nix filesystem.
  # Back up only the dedicated VirtioFS data volume on this host.
  lantian.backup.paths = lib.mkForce {
    nvme-nixos-home-vm = {
      snapshotFrom = "/nix/persistent/var/lib/vz/virtiofs";
      snapshotTo = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm";
      backupPath = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm/virtiofs/nixos-home-vm/persistent";
    };
  };

  services.proxmox-ve.bridges = [ "br-wan" "br-lan" ];
  services.proxmox-ve.ipAddress = LT.this.interconnect.IPv4;

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
    "${LT.hosts.ml-builder.interconnect.IPv4}" = [ "ml-builder.zhyi.cc" ];
  };
  networking.nameservers = lib.mkForce [
    "198.19.0.253"
    "223.5.5.5"
  ];

  # WAN bridge: eth1 → Router VM uplink from OpenWrt LAN.
  systemd.network.netdevs.br-wan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-wan";
    };
  };

  # LAN bridge: eth0 and VMs behind Router VM.
  systemd.network.netdevs.br-lan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-lan";
    };
  };

  systemd.network.networks = {
    "10-pve-lan" = {
      matchConfig.Name = "eth0";
      networkConfig.Bridge = "br-lan";
      linkConfig.RequiredForOnline = "enslaved";
    };

    "10-pve-wan" = {
      matchConfig.Name = "eth1";
      networkConfig.Bridge = "br-wan";
      linkConfig.RequiredForOnline = "no";
    };

    br-lan = {
      address = [ "${LT.this.interconnect.IPv4}/24" ];
      gateway = [ "192.168.0.1" ];
      matchConfig.Name = "br-lan";
      networkConfig.IPv6AcceptRA = "yes";
    };
  };
}
