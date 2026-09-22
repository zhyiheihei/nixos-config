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
    # iGPU（1002:164c Vega 8 + 1002:1637 HDMI 音频）直通 Win11 VM：IOMMU 开启、
    # 直通模式、vfio 早绑定（在 amdgpu 抢占前扣住设备）。
    "amd_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=1002:164c,1002:1637"
  ];
  # lantian-cachy 内核缺 dm_thin_pool（local-lvm 薄池承载全部 VM 磁盘），
  # 不加载则 VM 磁盘 LV 无法激活。
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
  # The active Btrfs swapfile prevents snapshotting the whole /nix filesystem.
  # Back up only the dedicated VirtioFS data volume on this host.
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

  # 核显 VAAPI/OpenGL：供 VM/LXC 共享 /dev/dri/renderD128 做硬编解码。
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = [ pkgs.mesa.drivers ];

  # 双 2.5G 口（I226-V）分段独立成桥：br-lan（eth0，主机地址+部分 VM）、
  # br-lan1（eth1，重负载 VM 专用段）。目标是多 VM 并行时不互相抢带宽：
  # 两段各占独立 2.5G 物理通道，跨段零抢占。单口桥结构上不可能成环，
  # 交换机侧零依赖（历史：曾尝试 bond 软聚合，但 active-backup 无提速、
  # TLB/ALB 在桥接宿主上会因源 MAC 固定导致交换机表漂移，均废弃；
  # eth1 原为 Router VM 的 WAN 腿，VM 已全部停机无承载）。
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

  # 纯 L2 段无 IP，需要 ConfigureWithoutCarrier 才会被 networkd 拉起。
  systemd.network.networks.br-lan1 = {
    matchConfig.Name = "br-lan1";
    networkConfig.ConfigureWithoutCarrier = true;
    linkConfig.RequiredForOnline = "no";
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
