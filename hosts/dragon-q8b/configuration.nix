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

    ../../nixos/optional-apps/kubo.nix
    ../../nixos/optional-apps/ncps.nix

    ../../nixos/optional-apps/redroid-gapps-image.nix
    ../../nixos/optional-apps/redroid.nix
  ];

  lantian.backup.enable = true;

  lantian.redroidGappsImage = {
    enable = true;
    mtgZip = pkgs.fetchurl {
      url = "https://github.com/MindTheGapps/13.0.0-arm64/releases/download/MindTheGapps-13.0.0-arm64-20231025_200931/MindTheGapps-13.0.0-arm64-20231025_200931.zip";
      hash = "sha256-P/LtqnVAbrQhRAL8ppBtS0E6tQr9sa8DPZ45aZIzjQs=";
    };
  };

  virtualisation.oci-containers.containers.redroid.cmd = [ "ro.setupwizard.mode=DISABLED" ];

  systemd.services.redroid-gapps-image.environment = LT.proxyEnvironment // {
    NO_PROXY = "${LT.proxyBypass},docker.m.daocloud.io";
  };

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;

  disabledModules = [
    ../../nixos/minimal-components/boot-params.nix
  ];

  boot.kernelParams = [
    "clk_ignore_unused"
    "pd_ignore_unused"
    "console=ttyMSM0,115200n8"
    "earlycon"
    "firmware_class.path=/lib/firmware"
  ];

  hardware.enableRedistributableFirmware = true;

  boot.initrd.extraFirmwarePaths = [
    "qcom/a660_sqe.fw.zst"
    "qcom/a660_gmu.bin.zst"
    "qcom/sc8280xp/LENOVO/21BX/qcdxkmsuc8280.mbn.zst"
    "qcom/sc8280xp/qcdxkmsuc8280.mbn.zst"
  ];

  environment.systemPackages = with pkgs; [
    qrtr
    alsa-ucm-conf
    nfs-utils
  ];

  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "noauto"
      "hard"
      "vers=4.1"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };

  systemd.units."mnt-storage.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
  };

  systemd.network.netdevs.bond0 = {
    netdevConfig = {
      Kind = "bond";
      Name = "bond0";
      MACAddress = "88:12:4e:00:03:54";
    };
    bondConfig = {
      Mode = "802.3ad";
      TransmitHashPolicy = "layer3+4";
      LACPTransmitRate = "fast";
      MIIMonitorSec = "100ms";
    };
  };

  systemd.network.networks.eth0 = {
    matchConfig.PermanentMACAddress = "88:12:4e:00:03:54";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.eth1 = {
    matchConfig.PermanentMACAddress = "88:12:4e:00:03:55";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.bond0 = {
    matchConfig.Name = "bond0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    dns = [ "192.168.0.1" ];
    domains = [ "zhyi.xin" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@bond0.service" ];

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.xin"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

  systemd.services.archivebox = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
  };

  zramSwap.enable = lib.mkForce false;
  swapDevices = [
    {
      device = "/nix/swap/swapfile";
      size = 4096;
    }
  ];

  systemd.services.ncps.environment = LT.proxyEnvironment // {
    HTTP_PROXY = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    HTTPS_PROXY = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    http_proxy = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    https_proxy = "http://${LT.hosts.rock5c.interconnect.IPv4}:7892";
    NO_PROXY = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
    no_proxy = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
  };
}
