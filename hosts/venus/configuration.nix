{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    inputs.venus-mainline.nixosModules.venus
  ];

  lantian.kernel = pkgs.callPackage (inputs.venus-mainline + "/nixos/kernel.nix") { };

  # 厂商固件（ath11k WCN6851 hw1.1 + qca BT）不在 git 也不在 upstream linux-firmware，
  # fleet 构建机拿不到：先给 null 保证求值，等固件有 pin 住的来源（静态文件缓存/attic）再填。
  venus.firmware = null;

  # venus 只有 wlan0（ath11k）。板级模块负责五路电源/PCIe 重训/固定 MAC，这里只做关联与地址。
  # SSID 明文（跟 router 的 moli-rk-wifi 一样），密码走 sops（per-host/wifi/venus.yaml）。
  networking.usePredictableInterfaceNames = false;
  networking.wireless = {
    enable = true;
    interfaces = [ "wlan0" ];
    secretsFile = config.sops.secrets."venus-wifi-secrets".path;
    networks."moli-1004-backup".pskRaw = "ext:psk_venus";
  };
  # sops 解密后是一行 psk_venus=<PSK>（wpa_supplicant 的 secretsFile 格式）
  sops.secrets."venus-wifi-secrets" = {
    sopsFile = inputs.secrets + "/per-host/wifi/venus.yaml";
    key = "wpa-secrets";
  };
  systemd.services."wpa_supplicant-wlan0" = {
    requires = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };

  # fleet 策略（minimal-policies）：板级 net-watch 是只读诊断单元（读 /sys/class/net、
  # 写 /var/log），走 network 预设硬化并在 chroot 里绑它要用的路径；wpa_supplicant 补
  # Restart/RestartSec；板级 getty 默认 RestartSec=1，低于策略的 3s 下限。
  lantian.harden = {
    "venus-net-watch".enable = "network";
    # 上游 wpa_supplicant 单元自己用 RootDirectoryStartOnly 做 chroot，
    # 与 confinement.enable 互斥（systemd 不允许），所以只取硬化预设。
    "wpa_supplicant-wlan0" = {
      enable = "network";
      enableConfinement = false;
    };
  };
  systemd.services.venus-net-watch.serviceConfig.BindPaths = [
    "/sys"
    "/var/log"
  ];
  systemd.services."serial-getty@ttyGS0".serviceConfig.RestartSec = lib.mkForce 3;
  systemd.services."wpa_supplicant-wlan0".serviceConfig = {
    Restart = "always";
    RestartSec = 3;
  };

  systemd.network.networks."10-wlan0" = {
    matchConfig.Name = "wlan0";
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
}
