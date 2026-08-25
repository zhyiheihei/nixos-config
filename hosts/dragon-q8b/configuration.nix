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

  boot.kernelParams = [
    "clk_ignore_unused"
    "pd_ignore_unused"
    "console=ttyMSM0,115200n8"
    "earlycon"
    # GPU 驱动（内建=y）在启动早期 probe，此时 udev 还没设置 firmware_class.path。
    # 显式设置让 GPU 驱动能从 initrd 的 /lib/firmware 加载 ZAP shader 固件。
    "firmware_class.path=/lib/firmware"
  ];

  hardware.enableRedistributableFirmware = true;

  # 确保 initrd 包含 GPU ZAP shader 固件，让 GPU 驱动在启动时能加载。
  # firmware_class.path=/lib/firmware 让内核从 initrd 的 /lib/firmware 搜索。
  boot.initrd.extraFirmwarePaths = [
    "qcom/sc8280xp/LENOVO/21BX/qcdxkmsuc8280.mbn.zst"
    "qcom/sc8280xp/qcdxkmsuc8280.mbn.zst"
  ];

  # Qualcomm SC8280XP userspace services.  qrtr nameserver is built into
  # the kernel (CONFIG_QCOM_RMTFS_MEM=y), pd-mapper is not needed since 6.11.
  # rmtfs provides remote filesystem access for modem/audio.
  environment.systemPackages = with pkgs; [
    qrtr
    rmtfs
    alsa-ucm-conf
    (callPackage ../../pkgs/pd-mapper {})
  ];

  systemd.services.rmtfs = {
    description = "Qualcomm Remote Filesystem Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rmtfs}/bin/rmtfs";
      Restart = "always";
      RestartSec = "10";
    };
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
}
