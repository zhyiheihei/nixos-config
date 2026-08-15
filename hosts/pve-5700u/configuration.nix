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

    # Pull /nix/sync-servers (ACME certs + ltnet-scripts data) from the
    # greencloud primary so pveproxy can serve the fleet-synced Let's Encrypt
    # certificate. pve.nix alone does not include minimal-apps.
    ../../nixos/minimal-apps/rsync-server.nix

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

  # pveproxy serves its own UI certificate.  The fleet ACME pipeline already
  # issues lets-encrypt-pve-5700u.zhyi.cc (base + wildcard) on greencloud and
  # syncs it through /nix/sync-servers; install it as pveproxy-ssl so the
  # homepage entry https://pve-5700u.zhyi.cc:8006 presents a trusted cert
  # instead of the stale self-signed CN=pve-5700u.lantian.pub fallback.
  systemd.services.pve-proxy-cert-install = {
    description = "Install synced Let's Encrypt cert into pveproxy";
    after = [ "rsync-nix-sync-servers.service" ];
    wants = [ "rsync-nix-sync-servers.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "pve-proxy-cert-install" ''
        set -euo pipefail
        certDir=/nix/sync-servers/acme/lets-encrypt-pve-5700u.zhyi.cc-ecc
        if [ ! -f "$certDir/fullchain.pem" ] || [ ! -f "$certDir/key.pem" ]; then
          exit 0
        fi
        # /etc/pve is pmxcfs (FUSE): chmod is not allowed there, so install
        # the certificate through the PVE CLI which writes pveproxy-ssl with
        # the correct modes.
        ${pkgs.pve-manager}/bin/pvenode cert set "$certDir/fullchain.pem" "$certDir/key.pem"
        ${pkgs.systemd}/bin/systemctl try-restart pveproxy.service
      '';
    };
  };

  # Re-run the installer whenever the synced cert changes (ACME renewal).
  systemd.paths.pve-proxy-cert-install = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      Unit = "pve-proxy-cert-install.service";
      PathChanged = "/nix/sync-servers/acme/lets-encrypt-pve-5700u.zhyi.cc-ecc";
    };
  };
}
