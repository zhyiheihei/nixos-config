{
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ./home-services.nix
    ./media-automation.nix

    # 从 opi5p 迁入（2026-08-28）：ncps 缓存代理与 Resilio Sync 引擎。
    # opi5p 侧同步移除（configuration.nix / media-center.nix）。
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/resilio-sync.nix

    # 从 opi5p 迁入（2026-08-30，按 §5.2 原计划）：Home Assistant + MQTT
    # broker（LTNET 监听，frigate 自 opi5p 远端发布）。数据自快照恢复副本
    # 迁入 /nix/persistent/var/lib/home-assistant；frigate 本体留在 opi5p
    #（RK3588 硬解），集成 URL 指 opi5p:5000。
    ../../nixos/optional-apps/home-assistant.nix
  ];

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;

  # server 角色统一加 nofb/nomodeset/vga=normal（nixos/server-components/boot-params.nix），
  # 但 nomodeset 会让 DRM 驱动拒绝 probe（日志表现 adev bind failed -19），
  # GPU/DPU/DisplayPort 音频全部瘫痪。kernelParams 是追加合并没有单删语法，
  # mkForce 手工重列又会把 root=fstab/nohibernate/lsm 等模块级参数全部顶掉
  # （已在 2026-08-25 踩过：gpt-auto-root 超时进 emergency）。
  # 此模块在本机只制 grub memtest/netboot.xyz（x86 专用，aarch64 全是空操作），
  # 直接 disabledModules 禁掉最干净。
  disabledModules = [ ../../nixos/server-components/boot-params.nix ];

  boot.kernelParams = [
    "clk_ignore_unused"
    "pd_ignore_unused"
    "console=ttyMSM0,115200n8"
    "earlycon"
    # msm 模块在 initrd 阶段加载，显式设置固件搜索路径（覆盖 udev 后期设置）。
    "firmware_class.path=/lib/firmware"
  ];

  hardware.enableRedistributableFirmware = true;

  # 确保 initrd 包含 GPU 固件，msm 模块在 initrd 阶段 probe 时就要加载：
  #   a660_sqe.fw / a660_gmu.bin — Adreno 690 SQE + GMU 固件
  #   qcdxkmsuc8280.mbn — ZAP shader（Radxa dts 复用 LENOVO/21BX，SoC unfused）
  boot.initrd.extraFirmwarePaths = [
    "qcom/a660_sqe.fw.zst"
    "qcom/a660_gmu.bin.zst"
    "qcom/sc8280xp/LENOVO/21BX/qcdxkmsuc8280.mbn.zst"
    "qcom/sc8280xp/qcdxkmsuc8280.mbn.zst"
  ];

  # Qualcomm SC8280XP userspace packages.  qrtr for remoteproc diagnostics,
  # alsa-ucm-conf for audio.
  #
  # rmtfs/pd-mapper NOT installed: this board has no modem (only adsp/cdsp
  # remoteprocs, no rmtfs-mem node in DTB), rmtfs has nothing to serve.
  environment.systemPackages = with pkgs; [
    qrtr
    alsa-ucm-conf
    nfs-utils
  ];

  # NAS 媒体库直接由 NAS 导出，与 opi5p/rock5c 挂同一个 NFS share。
  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "hard"
      "vers=4.1"
      "nconnect=16"
    ];
  };

  systemd.network.networks."10-dragon-q8b-lan" = {
    matchConfig.Name = "eth0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

  # NFS 媒体库挂载需要等物理网络就绪。通用策略禁用了全局 wait-online，
  # 这里启用按接口的实例。
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@eth0.service" ];

  # 容器镜像加速：通过 tencent 上的 hubproxy（hub.tencent.zhyi.xin，走
  # ZeroTier/LTNET 隧道）拉取 docker.io 镜像，daocloud 作为后备。
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.xin"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

  # ArchiveBox 绑定 NFS 媒体库，必须在挂载后启动。
  systemd.services.archivebox = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
  };

  # 关闭 zram（2026-08-28，与 opi5p 同款修复）：本机内存 8G，迁入 Resilio
  # （~2.4G RSS）与 bitmagnet/postgres 后服务密度接近物理内存上限。zram 的
  # zstd 压缩在内存吃满时让 kswapd 吃满一个核，陷入 swap 风暴死亡螺旋
  # （opi5p 已实测 load 181）。改用 NVMe swap 文件兜底。
  zramSwap.enable = lib.mkForce false;
  swapDevices = [
    { device = "/nix/swapfile"; size = 4096; }
  ];

  # Resilio Sync 引擎从 opi5p 迁入（2026-08-28）。identity/索引状态
  # （/var/lib/resilio-sync，4.4G）已 rsync 到本机持久盘；同步的文件夹
  # 数据本体在 NAS（/mnt/storage/resilio/*，与 opi5p 同一 NFS share，
  # 模块 bind 到 /sync 与 /downloads，数据库里的路径无需改动）。
  lantian.resilioSync = {
    dataDir = "/mnt/storage/resilio/data";
    downloadsDir = "/mnt/storage/resilio/downloads";
  };

  # NCPS 上游（cache.nixos.org / attic 等）需走 router SOCKS5 出口；
  # ncps.nix 模块只定义监听地址与缓存参数，代理环境在这里补齐
  # （与 opi5p configuration.nix 的同名块一致）。
  systemd.services.ncps.environment = {
    HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
    http_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    https_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  };
}
