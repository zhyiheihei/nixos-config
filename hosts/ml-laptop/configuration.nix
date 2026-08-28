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
    # ../../nixos/optional-apps/leigod-accelerator.nix
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

  # 雷电坞 eGPU（RTX 2080 Ti via TBT3 Oculink dock）稳定性修复，仅本机。
  # 2026-08-28 排障结论：595.x 驱动即使在禁用 GSP 固件后，遗留代码路径
  # 在 Turing + 雷电 3 eGPU 下仍存在根本性不兼容——nvidia-drm boot 时
  # 能初始化（仅读 PCI 配置空间），但首次 MMIO 访问（约 3 分钟后
  # Vulkan 进程触达）即 Xid 79，无 PCIe AER 错误，纯驱动↔GPU 通信失败。
  # 降级到 535 分支（早于 560+ GSP 强制启用时代）是当前最可行的方向。
  #
  # finegrained 关闭：公共 prime.nix 开了 RTD3 运行时休眠，eGPU 空闲
  # 几秒即被打入 D3cold，Turing 卡经雷电线唤醒失败会打死 GSP 固件 RPC。
  # 作者桌面卡（PCIe 直连）可以用它，本机雷电坞不行。
  hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
  hardware.nvidia.open = lib.mkForce false;

  # DXVK/VKD3D（Proton 的 DX11/DX12 转译层）默认取 Vulkan 枚举的首个设备，
  # 而 loader 按 ICD 文件名排序：intel 恒在 nvidia 之前，导致 DX12 游戏默认
  # 落在核显。会话级设备过滤器让所有 Proton 游戏自动落到 eGPU，无需每游戏
  # 手动配置。GL 游戏仍走 steam-offload（见 nvidia/prime.nix）。
  # 注意：拔掉 eGPU 后这两个过滤器会找不到设备，游戏内需自行清空该变量。
  environment.sessionVariables = {
    DXVK_FILTER_DEVICE_NAME = "NVIDIA GeForce RTX 2080 Ti";
    VKD3D_FILTER_DEVICE_NAME = "NVIDIA GeForce RTX 2080 Ti";
  };

  # eGPU 经雷电 3 隧道连接，PCI 总线号由雷电拓扑决定。公共 prime.nix
  # 硬编码 nvidiaBusId="PCI:1:0:0"（适用于 PCIe 直连 dGPU 如 lt-hp-omen），
  # 但本机 eGPU 实际在 0000:04:00.0（PCI:4:0:0）。BusId 不匹配会导致
  # X server PRIME offload 指向错误设备。
  hardware.nvidia.prime.nvidiaBusId = lib.mkForce "PCI:4:0:0";

  # 驱动降级 595.x → 535 分支（535.288.01）：535 分支早于 560+ 的 GSP
  # 强制启用时代，遗留代码路径是主路径且经过充分测试，对雷电 eGPU
  # 更友好。595.x 即使 NVreg_EnableGpuFirmware=0 禁了 GSP（确认 /proc
  # GPU Firmware: N/A），遗留路径仍首次 MMIO 即 Xid 79。
  hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidia_x11_legacy535;

  # 显式关闭驱动内部 RTD3（NVreg_DynamicPowerManagement=0），防止雷电
  # eGPU 被驱动主动打入 D3cold 后唤醒失败（Xid 154）。保留
  # powerManagement.enable 的 suspend/resume 视频内存保存功能。
  hardware.nvidia.moduleParams.nvidia.NVreg_DynamicPowerManagement = 0;

  # 显式禁用 GSP 固件。535 分支对 Turing 默认不加载 GSP，此参数作为
  # 保险。595.x 即使设此值，遗留路径仍不稳定（已实测确认）。
  hardware.nvidia.moduleParams.nvidia.NVreg_EnableGpuFirmware = 0;

  # 曾试过的修复（均在 595.x 驱动上，均未能阻止 Xid 79）：
  # - pci=realloc：雷电桥 memory window 未分配，eGPU 完全无法枚举。
  # - pcie_aspm=off：eGPU 卡在 D3cold 无法上电，JHL7440 在 ASPM 完全
  #   禁用后无法正常管理设备电源状态。
  # - NVreg_EnableGpuFirmware=0：GSP 确认未加载，但 595.x 遗留路径仍
  #   首次 MMIO 即失败。
  # 【结论已被 2026-08-28/29 实测推翻，见下方 eGPU 排障记录】降级 535
  # 只是把首次 Xid 79 从 3 分钟（负载）推迟到 1h43m（空载），不是修复。

  # eGPU 空载掉卡（Xid 79 "GPU has fallen off the bus"）排障记录，2026-08-29。
  #
  # 已实测排除的假说：
  # 1. 链路级 D3cold / 运行时 PM：TLP denylist + udev 强制 power/control=on
  #    + NVreg_DynamicPowerManagement=0 生效后，掉线时所有设备仍在 D0，
  #    无 Xid 154。
  # 2. 驱动分支：595.45.04 与 535.288.01 均掉（见上）。
  # 3. PCIe Completion Timeout：在根端口 00:07.0 禁用 CTO（DevCtl2
  #    TimeoutDis+，主机侧端口坞断电后仍保留）后 3 分钟内仍空载 Xid 79
  #    （2026-08-29 00:42:43）。注意：坞内交换芯片端口 02:00.0/03:04.0 的
  #    DevCtl2 只读，无法改。
  # 4. 硬件（坞供电/卡本体）：同一套硬件 Windows 下毫无故障。
  #
  # 重要教训：不要在驱动运行时改 GPU 端点（04:00.0）的 DevCtl2——RM 自己
  # 管理该寄存器，改完 RmInitAdapter 全部失败（0x22:0x56:774，该错误码
  # 历史上从未出现），只能坞断电重来。
  #
  # 掉线后软件无法恢复的两种实测形态：配置空间全 0xFF（lspci 报
  # "Unknown header type 7f"）时 remove+rescan 无效；配置空间尚在但 RM
  # 初始化失败时同样救不回。唯一恢复手段：坞断电重插。
  #
  # 当前实验（本轮）：移除 libvirt→vfio.nix 无条件带来的四个内核参数。
  # 本机 lantian.vfio.ids 为空、无任何直通设备，参数纯属死重；其中
  # pcie_acs_override 强制在下游端口（含雷电桥）伪造 ACS、改写 PCIe
  # 事务路由，且 Windows 下无此机制毫无故障——是剩余头号嫌疑。
  # AER 控制权在固件（_OSC 未授予 OS），所有链路级错误对内核不可见，
  # 掉线时 dmesg 只有 NVRM 三行是常态而非线索缺失。
  # 若验证有效：回头把 vfio.nix 的 kernelParams 改为按需启用（ids 非空
  # 才生效），本机的 mkForce 即可移除。
  boot.kernelParams = lib.mkForce [
    "i915.enable_guc=3"
    "cgroup_enable=memory"
    "delayacct"
    "ibt=off"
    "log_buf_len=1048576"
    "rcuupdate.rcu_cpu_stall_suppress=1"
    "split_lock_detect=off"
    "swapaccount=1"
    "net.ifnames=0"
    "psi=1"
  ];

  # eGPU（RTX 2080 Ti via Thunderbolt 3 Oculink dock）运行时电源管理修复。
  #
  # 根因：公共 client-components/tlp.nix 的 RUNTIME_PM_ON_AC=auto 对所有
  # PCIe 设备启用运行时 PM。eGPU 经雷电 3 链路连接，其附属功能（.2 USB
  # xHCI、.3 UCSI）进入 D3cold 后无法经雷电线唤醒（dmesg 实测 "Unable to
  # change power state from D3cold to D0, device inaccessible"），导致整卡
  # 不可访问、NVRM Xid 154（Node Reboot Required）。hardware.nvidia.
  # powerManagement.finegrained=mkForce false 只管 .0 VGA 功能的 RTD3，
  # 管不住 TLP 对 .2/.3 的运行时 PM。上游 lt-hp-omen 的 dGPU 是 PCIe 直连，
  # D3cold 唤醒无问题，故公共 tlp.nix 不做地址排除。
  #
  # 之前修复失败的根因：用了不存在的 TLP 选项名 PCIE_RUNTIME_PM_DENYLIST
  # 和带 0000: 前缀的地址格式。TLP 1.10.2 的正确选项名是
  # RUNTIME_PM_DENYLIST，地址格式同 lspci 第一列（不带 domain 前缀）。
  #
  # 修复两路：
  # 1. TLP RUNTIME_PM_DENYLIST：排除 eGPU 全部 4 条功能 + 上游雷电桥
  #    （03:02.0/03:04.0 已观测到 suspended）。
  # 2. udev 兜底：强制 power/control=on，防止 nvidia powerManagement 的
  #    bind udev 规则把 .0 设回 auto。udev KERNEL 用 sysfs 全名（带 0000:）。
  # PCIe 地址由雷电拓扑决定，dock/USB-C 口不变则固定。
  services.tlp.settings = {
    # eGPU 运行时 PM 排除（见上方注释）
    RUNTIME_PM_DENYLIST = lib.mkForce
      "02:00.0 03:01.0 03:02.0 03:04.0 04:00.0 04:00.1 04:00.2 04:00.3";

    # 笔记本解热能力有限：覆盖公共 client-components/tlp.nix 的 AC 策略。
    # 原版 AC 用 performance governor 恒定最高频（负载 0.65 也飙 4.3GHz/70°C）；
    # AC 改 schedutil 按负载动态调频（轻载自动降频、重载仍可 boost），
    # 能效策略 balance_power、平台档 balanced。电池模式仍是 powersave，不变。
    CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "schedutil";
    CPU_ENERGY_PERF_POLICY_ON_AC = lib.mkForce "balance_power";
    PLATFORM_PROFILE_ON_AC = lib.mkForce "balanced";
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
      ("${pkgs.writeShellScript "pam-verify-local-pin" ''
        hash_file="/var/lib/lantian-local-pin/pin.sha256"
        [ -r "$hash_file" ] || exit 1
        input=$(head -c 256)
        [ -n "$input" ] || exit 1
        calc="$(printf %s "$input" | sha256sum | cut -d" " -f1)" || exit 1
        printf %s "$calc" | cmp -s - "$(cat "$hash_file")"
      ''}")
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
