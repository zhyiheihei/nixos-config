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

    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/redroid.nix
  ];

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;

  # nomodeset 会让 msm DRM 拒绝 probe（adev bind failed -19），且 kernelParams
  # 只能追加、mkForce 重列会顶掉模块级参数，故 disabledModules 整块禁用。
  disabledModules = [ ../../nixos/server-components/boot-params.nix ];

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

  # noauto + automount：同 opi5p 修复（c72df01ca），archivebox 绑定 NFS。
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

  # 通用策略禁用全局 wait-online，NFS 挂载依赖按接口实例。
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
