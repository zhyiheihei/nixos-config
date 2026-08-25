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
  ];

  hardware.enableRedistributableFirmware = true;

  # Qualcomm SC8280XP userspace services: qrtr (IPC router), pd-mapper
  # (protection domain mapper, needed for audio/modem), rmtfs (remote
  # filesystem service).  Reference: ThinkPad X13s NixOS configs.
  environment.systemPackages = with pkgs; [
    qrtr
    rmtfs
    alsa-ucm-conf
    (callPackage ../../pkgs/pd-mapper { inherit qrtr; })
  ];

  systemd.services.qrtr = {
    description = "Qualcomm IPC Router";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.qrtr}/bin/qrtr-cfg";
      Restart = "always";
    };
  };

  systemd.services.pd-mapper = {
    description = "Qualcomm Protection Domain Mapper";
    after = [ "qrtr.service" ];
    requires = [ "qrtr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.callPackage ../../pkgs/pd-mapper { inherit qrtr; }}/bin/pd-mapper";
      Restart = "always";
    };
  };

  systemd.services.rmtfs = {
    description = "Qualcomm Remote Filesystem Service";
    after = [ "qrtr.service" ];
    requires = [ "qrtr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rmtfs}/bin/rmtfs";
      Restart = "always";
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
