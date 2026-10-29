{
  config,
  LT,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/hardware/lvm.nix
    ../../nixos/hardware/smart.nix
    ../../nixos/pve.nix

    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/netns-tnl-buyvm.nix
    ../../nixos/optional-apps/llama-cpp.nix
    ../../nixos/optional-apps/resin.nix
    ../../nixos/optional-apps/dlx.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/microsoft-rewards-script.nix

    ./enable-smart.nix
    ./hardware-configuration.nix
    ../../nixos/optional-cron-jobs/ncmm.nix
  ];

  boot.kernelParams = [
    "amd_pstate=active"
    "amd_pstate.shared_mem=1"

    "amd_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=1002:164c,1002:1637"
  ];

  boot.kernelModules = [ "dm_thin_pool" ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=1002:164c,1002:1637
    softdep amdgpu pre: vfio-pci
    softdep snd_hda_intel pre: vfio-pci
  '';

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  lantian.backup.enable = true;

  lantian.backup.paths = lib.mkForce {
    nvme-nixos-home-vm = {
      snapshotFrom = "/nix/persistent/var/lib/vz/virtiofs";
      snapshotTo = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm";
      backupPath = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm/virtiofs/nixos-home-vm/persistent";
    };
  };

  services.proxmox-ve.bridges = [
    "br-lan"
    "br-lan1"
  ];
  services.proxmox-ve.ipAddress = LT.this.interconnect.IPv4;

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
    "${LT.hosts.ml-builder.interconnect.IPv4}" = [ "ml-builder.zhyi.xin" ];
  };
  networking.nameservers = lib.mkForce [
    "198.19.0.253"
    "223.5.5.5"
  ];

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = [ pkgs.mesa.drivers ];

  systemd.network.netdevs.br-lan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-lan";
    };
  };

  systemd.network.netdevs.br-lan1 = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-lan1";
    };
  };

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.Bridge = "br-lan";
    linkConfig.RequiredForOnline = "enslaved";
  };

  systemd.network.networks.eth1 = {
    matchConfig.Name = "eth1";
    networkConfig.Bridge = "br-lan1";
    linkConfig.RequiredForOnline = "enslaved";
  };

  systemd.network.networks.br-lan = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    matchConfig.Name = "br-lan";
    networkConfig.IPv6AcceptRA = "yes";
  };

  systemd.network.networks.br-lan1 = {
    matchConfig.Name = "br-lan1";
    networkConfig.ConfigureWithoutCarrier = true;
    linkConfig.RequiredForOnline = "no";
  };

  systemd.services.pve-proxy-cert-install = {
    description = "Install synced Let's Encrypt cert into pveproxy";
    after = [ "rsync-nix-sync-servers.service" ];
    wants = [ "rsync-nix-sync-servers.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "pve-proxy-cert-install" ''
        set -euo pipefail
        certDir=/nix/sync-servers/acme/lets-encrypt-pve-5700u.zhyi.xin-ecc
        if [ ! -f "$certDir/fullchain.pem" ] || [ ! -f "$certDir/key.pem" ]; then
          exit 0
        fi
        # /etc/pve is pmxcfs (FUSE): chmod is not allowed there, so install
        # the certificate through the PVE CLI which writes pveproxy-ssl with
        # the correct modes.
        ${pkgs.pve-manager}/bin/pvenode cert set "$certDir/fullchain.pem" "$certDir/key.pem" --force
        ${pkgs.systemd}/bin/systemctl try-restart pveproxy.service
      '';
    };
  };

  systemd.paths.pve-proxy-cert-install = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      Unit = "pve-proxy-cert-install.service";
      PathChanged = "/nix/sync-servers/acme/lets-encrypt-pve-5700u.zhyi.xin-ecc";
    };
  };
}
