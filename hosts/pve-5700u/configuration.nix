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
  # The active Btrfs swapfile prevents snapshotting the whole /nix filesystem.
  # Back up only the dedicated VirtioFS data volume on this host.
  lantian.backup.paths = lib.mkForce {
    nvme-nixos-home-vm = {
      snapshotFrom = "/nix/persistent/var/lib/vz/virtiofs";
      snapshotTo = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm";
      backupPath = "/nix/persistent/var/lib/vz/virtiofs/.snapshot-nixos-home-vm/virtiofs/nixos-home-vm/persistent";
    };
  };

  services.proxmox-ve.bridges = [ "br-lan" ];
  services.proxmox-ve.ipAddress = LT.this.interconnect.IPv4;

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
    "${LT.hosts.ml-builder.interconnect.IPv4}" = [ "ml-builder.zhyi.xin" ];
  };
  networking.nameservers = lib.mkForce [
    "198.19.0.253"
    "223.5.5.5"
  ];

  # 双 2.5G 口（I226-V）做 active-backup 软聚合。历史：两块口曾是 Router VM
  # 的 WAN/LAN 腿，但 VM 全部停机、br-wan 无承载，且交换机侧聚合组已满
  # （.11 仅聚合1/聚合2）。桥接宿主上 TLB/ALB 会因源 MAC 固定导致交换机表
  # 漂移，active-backup 是无交换机配合时唯一可靠模式：主备秒切、零环路。
  # 写法对齐 ml-2700/opi5p：永久 MAC 绑 slave，bond MAC 钉 eth0 烧录地址。
  # 本内核（lantian-cachy）不自动拉起 bonding 模块，需显式加载。
  boot.kernelModules = [ "bonding" ];
  systemd.network.netdevs.bond0 = {
    netdevConfig = {
      Kind = "bond";
      Name = "bond0";
      MACAddress = "1c:83:41:40:c0:7a";
    };
    bondConfig = {
      Mode = "active-backup";
      MIIMonitorSec = "100ms";
    };
  };

  systemd.network.networks.eth0 = {
    matchConfig.PermanentMACAddress = "1c:83:41:40:c0:7a";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.eth1 = {
    matchConfig.PermanentMACAddress = "1c:83:41:40:c0:7b";
    networkConfig.Bond = "bond0";
  };

  # bond0 整体挂在 br-lan 下，主机地址与 VM 接入不变。
  systemd.network.networks.bond0 = {
    matchConfig.Name = "bond0";
    networkConfig.Bridge = "br-lan";
    linkConfig.RequiredForOnline = "enslaved";
  };

  # LAN bridge: bond0 and VMs behind Router VM.
  systemd.network.netdevs.br-lan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-lan";
    };
  };

  systemd.network.networks.br-lan = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    matchConfig.Name = "br-lan";
    networkConfig.IPv6AcceptRA = "yes";
  };

  # pveproxy serves its own UI certificate.  The fleet ACME pipeline already
  # issues lets-encrypt-pve-5700u.zhyi.xin (base + wildcard) on greencloud and
  # syncs it through /nix/sync-servers; install it as pveproxy-ssl so the
  # homepage entry https://pve-5700u.zhyi.xin:8006 presents a trusted cert
  # instead of the stale self-signed CN=pve-5700u.zhyi.xin fallback.
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

  # Re-run the installer whenever the synced cert changes (ACME renewal).
  systemd.paths.pve-proxy-cert-install = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      Unit = "pve-proxy-cert-install.service";
      PathChanged = "/nix/sync-servers/acme/lets-encrypt-pve-5700u.zhyi.xin-ecc";
    };
  };
}
