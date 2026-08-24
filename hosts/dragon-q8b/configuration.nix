{
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ./hardware-configuration.nix
  ];

  # Qualcomm SC8280XP (Snapdragon 8cx Gen 3) UEFI board, like the ThinkPad
  # X13s.  The Radxa Q8B UEFI firmware passes the board DTB to the kernel
  # itself, so no dtb= parameter or extra bootloader files are needed here.
  # SC8280XP UEFI firmware boots via systemd-boot, not GRUB.  The common
  # boot-params module enables GRUB by default; disable it explicitly.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;

  boot.kernelParams = [
    "clk_ignore_unused"
    "pd_ignore_unused"
    # Radxa OS 官方启动参数：串口输出内核日志，便于诊断启动/网卡问题
    "console=ttyMSM0,115200n8"
    "earlycon"
  ];

  # The mainline kernel already contains the SC8280XP platform drivers; the
  # TC956x 2.5GbE pairs load from the auxiliary bus automatically.

  hardware.enableRedistributableFirmware = true;

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
