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

  # server 角色给所有服务器加 nofb/nomodeset/vga=normal（见
  # nixos/server-components/boot-params.nix），但 nomodeset 会让 DRM 驱动拒绝
  # probe（日志表现 adev bind failed -19），GPU/DPU/DisplayPort 音频全部瘫痪。
  # kernelParams 是追加合并、无法单独移除某项，只能 mkForce 重建完整列表。
  # 前 7 项复制自 nixos/minimal-components/kernel.nix 的基础参数，上游改动需同步。
  boot.kernelParams = lib.mkForce [
    "cgroup_enable=memory"
    "delayacct"
    "ibt=off"
    "log_buf_len=1048576"
    "rcuupdate.rcu_cpu_stall_suppress=1"
    "split_lock_detect=off"
    "swapaccount=1"
    "clk_ignore_unused"
    "pd_ignore_unused"
    "console=ttyMSM0,115200n8"
    "earlycon"
    # msm 模块在 initrd 阶段加载，显式设置固件搜索路径（覆盖 udev 后期设置）。
    "firmware_class.path=/lib/firmware"
  ];

  hardware.enableRedistributableFirmware = true;

  # 确保 initrd 包含 GPU ZAP shader 固件，让 GPU 驱动在启动时能加载。
  # firmware_class.path=/lib/firmware 让内核从 initrd 的 /lib/firmware 搜索。
  boot.initrd.extraFirmwarePaths = [
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
