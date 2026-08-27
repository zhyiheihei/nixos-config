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

    # 与上游 lt-hp-omen 逐字对齐的 optional-apps 导入列表（含注释占位）。
    ../../nixos/optional-apps/audio-cpp.nix
    ../../nixos/optional-apps/byparr.nix
    # ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/homepage.nix
    ../../nixos/optional-apps/libvirt
    ../../nixos/optional-apps/llama-cpp.nix
    ../../nixos/optional-apps/netns-tnl-buyvm.nix
    ../../nixos/optional-apps/nix-distributed.nix
    ../../nixos/optional-apps/obs-studio.nix
    ../../nixos/optional-apps/opencl.nix
    # ../../nixos/optional-apps/pipewire-noise-cancelling.nix
    ../../nixos/optional-apps/pipewire-roc-sink.nix
    # ../../nixos/optional-apps/qdrant.nix
    ../../nixos/optional-apps/samba.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/virtualbox.nix
    ../../nixos/optional-apps/vlmcsd.nix
    ../../nixos/optional-apps/whisper-cpp.nix

    # 本机保留（上游 lt-hp-omen 列表之外的必要项）：
    # - Sunshine：本机是 Moonlight 远程控制的目标设备，串流服务端必须有。
    # - ncps-client：全仓各主机统一导入的局域网二进制缓存代理（ opi5p NCPS
    #   单一入口），属构建基础设施而非应用；删掉会回退直连公网缓存，显著变慢。
    # - leigod-accelerator：雷神加速器后台守护（官方无 Linux 桌面版，基于
    #   SteamDeck 插件二进制移植，模块内注释有全部适配细节）。
    ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/ncps-client.nix
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

  # 与作者 lt-hp-omen 逐字对齐的 HiDPI（grub/console 字体缩放）。
  lantian.hidpi = 1.5;

  # 与上游 lt-hp-omen 逐字对齐：ROC 网络音频发送目标（pipewire-roc-sink 的
  # 接收端 IP）。不设则 roc-sink 导入为空操作；如接收端不同请按实际改。
  lantian.pipewire.roc-sink-ip = [
    "192.168.0.207"
  ];

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

  # 对齐上游 lt-hp-omen：sddm X11 DPI、触摸板手势、waydroid、usbmuxd。
  # sddm 跑在 X11 上（登录界面），plasma session 走 wayland（kde.nix 默认）。
  services.displayManager.sddm.settings.X11.ServerArguments = "-dpi 144";
  services.libinput.touchpad = {
    accelSpeed = "0.4";
    clickMethod = "clickfinger";
    disableWhileTyping = false;
  };

  virtualisation.waydroid.enable = true;
  services.usbmuxd.enable = true;
  systemd.services.usbmuxd.serviceConfig.Restart = "always";

  # 对齐上游 lt-hp-omen：手柄驱动。
  hardware.xpadneo.enable = true;

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  # Host-level override (optional-apps/sunshine.nix is a public module, left
  # untouched): allow browser access to the Sunshine Web UI from LAN / LTNET,
  # otherwise CSRF protection blocks the pairing page.  Comma-separated because
  # the settings option only accepts atom values.
  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.55:47990,https://198.18.0.118:47990,https://ml-laptop.zhyi.xin:47990";

  # NVIDIA 是雷电坞外接 eGPU：未连接时 nvidia 内核模块不加载，
  # nvidia-container-toolkit-cdi-generator（公共模块 hardware/nvidia/prime.nix
  # 经 hardware.nvidia-container-toolkit.enable 引入）会因 NVML "Driver Not
  # Loaded" 硬失败，中止 switch-to-configuration，导致 colmena apply 报
  # "Child process exited with error code: 4"。仅在本机加在位条件：模块已加载
  # （/proc/driver/nvidia/version 存在 ⇔ eGPU 在位，模块由 udev 按设备加载）
  # 才运行；否则 unit 为 skipped，不影响激活。eGPU 在位时行为与上游一致。
  # 热插拔接入后如需立即生成 CDI spec，手动 restart 该 unit 即可。
  # eGPU 雷电授权持久化：固件不记 thunderbolt authorized 状态，重启后
  # authorized=0，PCIe 隧道不建立、驱动不加载。boltd 用 boot ACL 记住
  # 已授权设备，重启自动重新授权。首次仍需手动一次：
  #   boltctl authorize --policy auto bb030000-0070-7c0e-033f-e425de412825
  services.hardware.bolt.enable = true;

  systemd.services.nvidia-container-toolkit-cdi-generator.unitConfig.ConditionPathExists =
    "/proc/driver/nvidia/version";

  # 雷电坞 eGPU（RTX 2080 Ti）稳定性修复，仅本机：
  # 公共 prime.nix 开了 finegrained（RTD3 运行时休眠），eGPU 空闲几秒即被
  # 打入 D3cold；Turing 卡经雷电线唤醒失败会直接打死 GSP 固件 RPC——表现为
  # nvidia-smi 枚举不到设备（Sunshine 因此回落 Intel 核显 VAAPI 导致串流
  # 卡顿）、NVRM 反复 assert，甚至关机都被 D3cold→D0 失败卡死。见 2026-08-27
  # 排障记录。故 finegrained 必须关：作者桌面卡（PCIe 直连、无雷电唤醒
  # 问题）可以用它，本机雷电坞不行。代价是 eGPU 不再自动省电；待闭源
  # 驱动跑稳后，如需找回深度省电可单独实验改回 true（届时观察是否复现）。
  #
  # 驱动切换为闭源内核模块，与上游 lt-hp-omen 的主机级覆盖完全一致（作者
  # 在 omen 上同样对 Turing 卡强制 open=false）：Turing 代际官方推荐闭源，
  # 且电源管理走传统消息机制，较 open 模块的 GSP 模式在雷电流下更成熟。
  # 若后续仍出现 GSP 类故障，下一步备选是再加
  # options nvidia NVreg_EnableGpuFirmware=0 关掉 GSP 固件。
  hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
  hardware.nvidia.open = lib.mkForce false;

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

  # eGPU 是 RTX 2080 Ti（Turing, sm_75）。nixpkgs 默认给 llama-cpp 编译
  # sm_75～sm_121a 共 8 种 arch，CUDA 12.9 的 ptxas 在处理 fattn-mma-f16
  # 模板实例时 segfault（signal 11）。限制只编译 sm_75 即可避开，同时也
  # 大幅缩短构建时间。
  nixpkgs.config.cudaArches = [ "sm_75" ];
}
