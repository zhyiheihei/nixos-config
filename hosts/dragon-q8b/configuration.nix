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

    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/resilio-sync.nix
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

  # 关 zram 改 NVMe swapfile（与 opi5p 同款：服务密度超物理内存后 zram
  # 压缩致 swap 风暴）；swapfile 在独立子卷 /nix/swap，避免 /nix 快照 EBUSY。
  zramSwap.enable = lib.mkForce false;
  swapDevices = [
    {
      device = "/nix/swap/swapfile";
      size = 4096;
    }
  ];

  # Resilio Sync 数据本体在 NAS（与 opi5p 同一 NFS share，数据库路径不变）。
  lantian.resilioSync = {
    dataDir = "/mnt/storage/resilio/data";
    downloadsDir = "/mnt/storage/resilio/downloads";
  };

  # NCPS 上游代理：router V2Ray（LT.proxyEnvironment）在 2026-09-05 间歇性
  # 断流，导致 NCPS 替代下载超时、全集群 substituter 退化。改走 rock5c 的
  # metacubexd mihomo mixed 口（metacubexd.nix 里 MIXED_PORT=7892 且发布在
  # rock5c LAN 地址上）。m-team 豁免照旧。
  systemd.services.ncps.environment = LT.proxyEnvironment // {
    HTTP_PROXY = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    HTTPS_PROXY = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    http_proxy = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    https_proxy = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    NO_PROXY = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
    no_proxy = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
  };
}
