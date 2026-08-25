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
  ];

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
}
