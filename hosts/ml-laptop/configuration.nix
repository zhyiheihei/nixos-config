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
    ../../nixos/optional-apps/homepage.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/pipewire-combined-sink-alsa.nix
    ../../nixos/optional-apps/pipewire-roc-source.nix
    ../../nixos/optional-apps/pipewire-vban-recv.nix
    ../../nixos/optional-apps/pipewire-volume-control.nix
    ../../nixos/optional-apps/samba.nix
    ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/syncthing
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

  # 与作者 lt-hp-omen 逐字对齐的 HiDPI（grub/console 字体缩放）。
  lantian.hidpi = 1.5;

  # 与作者 lt-hp-omen 逐字对齐的 home SMB 共享（force user/valid 改 zhyi）。
  services.samba.settings = {
    "zhyi" = {
      "path" = "/home/zhyi";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "create mask" = "0644";
      "directory mask" = "0755";
      "force user" = "zhyi";
      "force group" = "zhyi";
      "valid users" = "zhyi";
      "veto files" = "/._*/.DS_Store/Thumbs.db/";
      "delete veto files" = "yes";
    };
  };

  # Bind mounts
  fileSystems = {
    # keep-sorted start block=yes
    "/home/zhyi/.local/share/ManosabaMod" = lib.mkForce {
      device = "/nix/persistent/media/ManosabaMod";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/.local/share/yuzu" = lib.mkForce {
      device = "/nix/persistent/media/Yuzu";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Backups" = lib.mkForce {
      device = "/nix/persistent/media/Backups";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Books" = lib.mkForce {
      device = "/nix/persistent/media/Books";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Calibre Library" = lib.mkForce {
      device = "/nix/persistent/media/Calibre Library";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Documents" = lib.mkForce {
      device = "/nix/persistent/media/Documents";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/LegacyOS" = lib.mkForce {
      device = "/nix/persistent/media/LegacyOS";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Music/CloudMusic" = lib.mkForce {
      device = "/nix/persistent/media/CloudMusic";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Music/CloudMusicArchive" = lib.mkForce {
      device = "/nix/persistent/media/CloudMusicArchive";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Pictures" = lib.mkForce {
      device = "/nix/persistent/media/Pictures";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Secrets" = lib.mkForce {
      device = "/nix/persistent/media/Secrets";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Software" = lib.mkForce {
      device = "/nix/persistent/media/Software";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Videos/VideoArchive" = lib.mkForce {
      device = "/nix/persistent/media/VideoArchive";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    # keep-sorted end
  };

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  # Host-level override (optional-apps/sunshine.nix is a public module, left
  # untouched): allow browser access to the Sunshine Web UI from LAN / LTNET,
  # otherwise CSRF protection blocks the pairing page.  Comma-separated because
  # the settings option only accepts atom values.
  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.55:47990,https://198.18.0.118:47990,https://ml-laptop.zhyi.xin:47990";

  # 笔记本解热能力有限：覆盖公共 client-components/tlp.nix 的 AC 策略。
  # 原版 AC 用 performance governor 恒定最高频（负载 0.65 也飙 4.3GHz/70°C）；
  # 这里 AC 改 schedutil 按负载动态调频（轻载自动降频、重载仍可 boost），
  # 能效策略 balance_power、平台档 balanced。电池模式仍是 powersave，不变。
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "schedutil";
    CPU_ENERGY_PERF_POLICY_ON_AC = lib.mkForce "balance_power";
    PLATFORM_PROFILE_ON_AC = lib.mkForce "balanced";
  };

  # 蓝牙：AX211 蓝牙硬件已识别（hci0），启用 bluetooth 服务让蓝牙可用。
  # 用作者写法 hardware.bluetooth（services.bluetooth 无此选项会导致整机 eval 失败）。
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  # 主网络走 NetworkManager（client 默认）。临时有线网卡和 WiFi 均由其接管；
  # 首次安装验收后建议在目标机用 nmcli 把 WiFi 连接配成静态 192.168.0.55，
  # 连接会被持久化到 /etc/NetworkManager/system-connections（client.nix 已
  # 把该目录加入 preservation），无需把密码写进本仓库。

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

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };

  # ml-laptop 在国内，Docker Hub 不可达。优先走自家 hubproxy
  # （hub.tencent.zhyi.xin），daocloud 兜底。
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.xin"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';
}
