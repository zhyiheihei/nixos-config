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

    # 与上游 lt-dell-wyse 对齐的本机文件；wireplumber 规则中的 PCI 卡路径
    # 是 wyse 机型的，需换成本机 HDMI 音频卡名后才生效（见该文件内注释）。
    ./wireplumber-disable-hdmi-audio.nix
    # ./xvcd.nix

    # 与上游 lt-dell-wyse 逐字对齐的 optional-apps 导入列表（含注释占位）。
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/pipewire-combined-sink-alsa.nix
    # ../../nixos/optional-apps/pipewire-network-audio-receive.nix
    ../../nixos/optional-apps/pipewire-roc-source.nix
    ../../nixos/optional-apps/pipewire-vban-recv.nix
    ../../nixos/optional-apps/pipewire-volume-control.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/leigod-accelerator.nix
  ];

  # 与作者 lt-hp-omen 逐字对齐的整机 restic 备份（路径 lantian→zhyi）。
  # client 默认不启用 backup（enable 默认 hasTag server），此处显式启用。
  lantian.backup = {
    enable = true;
    resticRepos = [ "home" ];
    paths = {
      nix-persistent = lib.mkForce {
        snapshotFrom = "/nix/persistent";
        snapshotTo = "/nix/.snapshot-persistent";
        backupPath = "/nix/.snapshot-persistent";
      };
      home = {
        snapshotFrom = "/nix/persistent/home";
        snapshotTo = "/nix/persistent/.snapshot-home";
        backupPath = "/nix/persistent/.snapshot-home/zhyi";
        ignored = ''
          .cache
          .cursor/extensions
          .local/share/containers
          .local/share/Steam/steamapps/common
          .local/share/Xilinx
          .vscode/extensions
          .windsurf/extensions
          Downloads
        '';
      };
    };
    schedule = "daily";
    persistentTimer = true;
  };

  # 划词翻译（Ctrl+Alt+E），KDE Wayland 下经 crow 的 D-Bus 接口触发。
  lantian.crow-translate.enable = true;

  # Host-level override (optional-apps/sunshine.nix is a public module, left
  # untouched): allow browser access to the Sunshine Web UI from LAN / LTNET,
  # otherwise CSRF protection blocks the pairing page. Comma-separated because
  # the settings option only accepts atom values.
  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.53:47990,https://198.18.0.113:47990,https://ml-2700.zhyi.xin:47990";

  # AMD APU (Vega 3): client-components/xorg.nix sets the Intel default
  # LIBVA_DRIVER_NAME=iHD, which breaks VA-API on this GPU. Override to
  # radeonsi so hardware encoding works.
  environment.variables.LIBVA_DRIVER_NAME = lib.mkForce "radeonsi";

  # The running user session inherited iHD at login, so /etc/environment alone
  # won't reach the sunshine user unit until the next login. Pin the variable
  # on the unit itself so it applies on restart.
  systemd.user.services.sunshine.environment.LIBVA_DRIVER_NAME = "radeonsi";

  # Force the mature VA-API hardware encoder. The default h264_vulkan (RADV)
  # produced blocky artifacts on this APU, and vaapi is only probed after
  # vulkan in Sunshine's encoder priority list.
  services.sunshine.settings.encoder = "vaapi";
  # 双千兆口接家庭交换机 S5700S（192.168.0.12）做 LACP 聚合出 2000M LAN。
  # 交换机侧对应 Eth-Trunk 1（LACP），两端必须同步配置。IP/网关从原 NM
  # 手工 profile（有线连接 2）迁到 networkd 声明，写法对齐 rock5c 的
  # home-lan 网络；eth0/eth1/bond0 从 NM 摘除，桌面 WiFi 等仍归 NM。
  # 按永久 MAC 绑定，防止探测顺序变化导致 slave 丢失。
  systemd.network.netdevs."10-bond0" = {
    netdevConfig = {
      Kind = "bond";
      Name = "bond0";
    };
    bondConfig = {
      Mode = "802.3ad";
      TransmitHashPolicy = "layer3+4";
      LACPTransmitRate = "fast";
      MIIMonitorSec = "100ms";
    };
  };

  systemd.network.networks."10-eth0-bond-slave" = {
    matchConfig.PermanentMACAddress = "1c:83:41:29:62:47";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks."10-eth1-bond-slave" = {
    matchConfig.PermanentMACAddress = "1c:83:41:29:62:48";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks."10-bond0" = {
    matchConfig.Name = "bond0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    dns = [ "192.168.0.1" ];
    domains = [ "zhyi.xin" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };

  networking.networkmanager.unmanaged = [
    "interface-name:eth0"
    "interface-name:eth1"
    "interface-name:bond0"
  ];

  # NFS share from the fork's file server (opi5p), mirroring the author's
  # client mount of lt-home-vm:/storage. Auto-mounted, non-blocking.
  fileSystems."/mnt/share" = {
    device = "${LT.hosts.opi5p.ltnet.IPv4}:/storage";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "noauto"
      "clientaddr=${LT.this.ltnet.IPv4}"
      "hard"
      "vers=4.2"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=5s"
    ];
  };

  # automount 触发的 mount 失败不再撞 5 次/10s 限流（同 lubancat1/opi5p，
  # 2453d5d96）：存储端离线恢复后访问即自愈。
  systemd.units."mnt-share.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
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
