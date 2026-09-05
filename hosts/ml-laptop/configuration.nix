{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/client.nix

    ./hardware-configuration.nix

    # 与上游 lt-hp-omen 逐字对齐的 optional-apps 导入列表（含注释占位）。
    ../../nixos/optional-apps/audio-cpp.nix
    ../../nixos/optional-apps/byparr.nix
    ../../nixos/optional-apps/clash-verge.nix
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
    # - Sunshine：Moonlight 串流服务端。
    # - ncps-client：局域网二进制缓存代理接入。
    # - hydra：CI（构建拓扑见 docs/agent/hydra-build-chain.md）。
    ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/hydra
    ../../nixos/client-apps/zcode.nix
    # ../../nixos/optional-apps/leigod-accelerator.nix
  ];

  # Hydra evaluator 直连 GitHub 拉 flake inputs 会长期卡死，注入出站代理。
  systemd.services.hydra-evaluator.environment = LT.proxyEnvironment;

  # 构建拓扑：本机零本地编译（max-jobs = 0，求值期 FOD 亦全部外派，
  # 遇慢镜像可能拖慢求值，属既定取舍）、不对外通告（host.nix 无
  # nix-builder 标签），详见 docs/agent/hydra-build-chain.md。
  nix.settings.max-jobs = 0;
  nix.buildMachines = lib.mkForce (
    let
      mk = n: maxJobs: features: {
        inherit (LT.hosts.${n}) system;
        hostName = "${n}.zhyi.xin";
        protocol = "ssh";
        speedFactor = LT.hosts.${n}.cpuThreads;
        sshKey = config.sops.secrets.hydra-builder-ssh-privkey.path;
        sshUser = "nix-builder";
        inherit maxJobs;
        supportedFeatures = features;
        mandatoryFeatures = [ ];
      };
    in
    [
      (mk "ml-builder" 2 [ "aarch64-cross" ])
      (mk "ml-builder" 1 [
        "big-parallel"
        "aarch64-cross"
      ])
      (mk "opi5p" LT.hosts.opi5p.cpuThreads [ ])
      (mk "opi5p" 1 [ "big-parallel" ])
    ]
  );
  services.hydra.buildMachinesFiles = lib.mkForce [ "/etc/nix/machines" ];

  # 本地 daemon 声明 aarch64-cross，与 ml-builder 的通告对齐（ARM 内核
  # 交叉构建带 requiredSystemFeatures 硬性要求）。
  nix.settings.extra-system-features = [ "aarch64-cross" ];

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

  lantian.zcode.enable = true;

  # HiDPI（1.6 与 KWin Wayland 输出缩放一致，X11/Wayland 视觉统一）。
  lantian.hidpi = 1.6;

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

  # waydroid 硬编码挂载 $XDG_RUNTIME_DIR/pulse/native，而本机 PipeWire
  # 跑在系统级（/var/run/pulse/native），缺链接则容器无法启动。
  systemd.user.tmpfiles.rules = [
    "L+ %t/pulse/native - - - - /var/run/pulse/native"
  ];

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

  # Sunshine 全栈固定核显（Intel）：eGPU(card0) 不驱任何显示器，而本版
  # Sunshine 的 nvenc 初始化要求编码 GPU 自带 monitor，导致每轮探测都
  # "Couldn't find monitor [0]" 失败（约 0.4s/轮），再回落 vulkan→vaapi。
  # 显式钉死 encoder=vaapi / capture=kms 跳过探测循环：KMS 命中的就是
  # 核显侧 HDMI-A-1 输出（prep_cmd 的 kscreen-doctor 也作用于此），
  # VA-API 由 client-components/xorg.nix 的 LIBVA_DRIVER_NAME=iHD 驱动。
  # upnp=false：本机在防火墙策略中永不做公网端口转发，UPnP 映射注定
  # 失败且每天刷百余条 "Failed to map ... 501" 日志噪音。
  services.sunshine.settings = {
    encoder = "vaapi";
    capture = "kms";
    # upnp = false;
  };

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

  # nixpkgs 6.12 LTS 内核覆写（eGPU TB3 稳定性对照，见 ml-laptop eGPU 文档）。
  lantian.kernel = lib.mkForce pkgs.linuxKernel.packages.linux_6_12.kernel;

  # eGPU 核心频率锁定 1500MHz（TB3 P-state 跳变失联的缓解，见 eGPU 文档）。
  systemd.services.egpu-clock-lock = {
    description = "Lock eGPU core clock to avoid TB3 P-state transition drops";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    wants = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # /proc/driver/nvidia/version 存在 ⇔ eGPU 在位（同 CDI generator 条件）
    unitConfig.ConditionPathExists = [ "/proc/driver/nvidia/version" ];
    script = ''
      ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pm 1
      ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -lgc 1500,1500
    '';
  };

  # 雷电坞 eGPU（RTX 2080 Ti via TBT3 Oculink dock）：完整排障记录、
  # 根因结论与防护层级见 docs/human/hardware/ml-laptop-egpu.md。
  hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
  hardware.nvidia.open = lib.mkForce false;

  # eGPU 实际在 0000:04:00.0（总线号由雷电拓扑决定，公共 prime.nix 按
  # PCIe 直连 dGPU 硬编码 PCI:1:0:0）。
  hardware.nvidia.prime.nvidiaBusId = lib.mkForce "PCI:4:0:0";

  # RTD3 防护：关驱动内部电源管理防 D3cold 唤醒失败（Xid 154）。
  hardware.nvidia.moduleParams.nvidia.NVreg_DynamicPowerManagement = 0;
  hardware.nvidia.moduleParams.nvidia.NVreg_EnableGpuFirmware = 0;

  # TLP 运行时 PM 排除（eGPU 全部 4 条功能 + 上游雷电桥；D3cold 唤醒
  # 失败即 Xid 154 的根因，见 eGPU 文档）。
  services.tlp.settings = {
    RUNTIME_PM_DENYLIST = lib.mkForce "02:00.0 03:01.0 03:02.0 03:04.0 04:00.0 04:00.1 04:00.2 04:00.3";

    # AC 模式：governor powersave（intel_pstate active 下即 HWP 自动调频，
    # performance/schedutil 均不可用）+ EPP performance + 平台档
    # performance（Linux 侧唯一有效风扇入口），详见 ml-laptop 文档。
    CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "powersave";
    CPU_ENERGY_PERF_POLICY_ON_AC = lib.mkForce "performance";
    PLATFORM_PROFILE_ON_AC = lib.mkForce "performance";
  };

  services.udev.extraRules = ''
    ACTION=="add|change|bind", SUBSYSTEM=="pci", KERNEL=="0000:02:00.0", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change|bind", SUBSYSTEM=="pci", KERNEL=="0000:03:0[124].0", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change|bind", SUBSYSTEM=="pci", KERNEL=="0000:04:00.[0-3]", TEST=="power/control", ATTR{power/control}="on"
  '';

  # 蓝牙：AX211 蓝牙硬件已识别（hci0），启用 bluetooth 服务让蓝牙可用。
  # 用作者写法 hardware.bluetooth（services.bluetooth 无此选项会导致整机 eval 失败）。
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  ########################################
  # 锁屏 PIN 码认证（主密码之外的便捷通道）
  ########################################

  # 在 kde（锁屏 greeter）PAM 栈里、kwallet 捕获之后与 pam_unix 之前
  # 插入 sufficient 的本地 PIN 校验：PIN 命中即直接放行，未命中继续走
  # 原主密码流程，两种凭据二选一。排序采用模块要求的相对偏移写法，
  # 避免 NixOS 内置 order 变动导致规则漂移。
  #
  # 设置/修改 PIN（部署后在目标机以 root 执行）：set-local-pin
  # 未设置或哈希文件缺失时本规则恒失败，行为与改动前完全一致。
  #
  # 安全边界说明：PIN 以 sha256 形式存于 /var/lib/lantian-local-pin
  # （root:0600，tmpfiles 创建）；在线爆破受 greeter 的
  # StartLimitBurst=5/500s 与 kscreenlocker 输入限速约束。请使用
  # ≥6 位且避免纯生日/重复模式；sudo/login/su 刻意不接入此通道，
  # 重要操作仍需完整主密码。
  security.pam.services.kde.rules.auth.local-pin = {
    order = config.security.pam.services.kde.rules.auth.kwallet.order + 100;
    control = "sufficient";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
    args = [
      "expose_authtok"
      "${pkgs.writeShellScript "pam-verify-local-pin" ''
        hash_file="/var/lib/lantian-local-pin/pin.sha256"
        [ -r "$hash_file" ] || exit 1
        input=$(head -c 256)
        [ -n "$input" ] || exit 1
        calc="$(printf %s "$input" | sha256sum | cut -d" " -f1)" || exit 1
        printf %s "$calc" | cmp -s - "$(cat "$hash_file")"
      ''}"
    ];
  };

  # 首次设置 PIN：root 运行 set-local-pin，交互输入两次。
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "set-local-pin" ''
      read -rsp "输入新 PIN（建议≥6位）: " p1; echo
      read -rsp "再次确认           : " p2; echo
      if [ -z "$p1" ] || [ "$p1" != "$p2" ]; then
        echo "为空或两次不一致，已取消"; exit 1
      fi
      install -d -m 0700 /var/lib/lantian-local-pin
      printf %s "$p1" | sha256sum | cut -d" " -f1 > /var/lib/lantian-local-pin/pin.sha256
      chmod 600 /var/lib/lantian-local-pin/pin.sha256
      echo "本地 PIN 已更新。锁屏解锁立即可用，无需重启。"
    '')
  ];

  systemd.tmpfiles.settings.lantian-local-pin."/var/lib/lantian-local-pin".d = {
    mode = "0700";
    user = "root";
    group = "root";
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

  # vlmcsd 经 netns.kms 广播 anycast KMS 地址，netns.nix（公共模块）为每个
  # enableBird 的 netns 起 netns-bird-${name} 服务，硬设 User/Group=bird。但
  # bird 用户只在 server-apps/bird（server 角色专属）里创建，client 不导入
  # 它，导致 netns-bird-kms 启动报 status=217/USER（用户不存在），colmena
  # apply 整体失败。主机级补 bird 用户/组，定义与 server-apps/bird 一致。
  users.users.bird = {
    description = "BIRD Internet Routing Daemon user";
    group = "bird";
    isSystemUser = true;
  };
  users.groups.bird = { };

  # eGPU 是 RTX 2080 Ti（Turing，compute capability 7.5）。CUDA 目标裁剪
  # （只编译 sm_75）不在本文件做：本仓库 pkgs 由 flake 在 NixOS 模块系统外
  # 构造后强制注入，nixpkgs.config.* 对包集不生效，实际开关是同目录的
  # cuda-capabilities.nix（flake-modules/nixos-configurations.nix 消费）。
}
