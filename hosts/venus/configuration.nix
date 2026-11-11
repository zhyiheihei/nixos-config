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

  lantian.kernel = pkgs.venus-kernel;

  venus.firmware = pkgs.venus-firmware;

  networking.usePredictableInterfaceNames = false;
  networking.wireless = {
    enable = true;
    interfaces = [ "wlan0" ];
    secretsFile = config.sops.secrets."venus-wifi-secrets".path;
    networks."moli-1004-backup".pskRaw = "ext:psk_venus";
  };
  sops.secrets."venus-wifi-secrets" = {
    sopsFile = inputs.secrets + "/per-host/wifi/venus.yaml";
    key = "wpa-secrets";
  };
  systemd.services."wpa_supplicant-wlan0" = {
    requires = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };

  # 26.11 的 stage-2 init 是 systemd 直接当 PID1，开机无人跑 activation；
  # 该单元在 systemd 挂好 /run 后执行当前 profile 的 activation，
  # 补齐 /run/current-system、/run/booted-system、固件路径与 /etc 同步
  systemd.services.venus-boot-activate = {
    description = "venus: boot-time NixOS activation";
    wantedBy = [ "multi-user.target" ];
    before = [
      "venus-wifi-power.service"
      "getty.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/nix/var/nix/profiles/system/activate";
    };
  };
  # 90 秒无网即 dd 回滚并重启的看门狗是单机自愈用的；fleet 角色下由 colmena 管回滚，
  # 且其计数器在持久层缺失导致每次开机归零、引导未完成就被重启
  systemd.services.venus-wifi-fallback.enable = lib.mkForce false;

  # wpa_supplicant-wlan0 的沙箱绑定 /dev/rfkill，devtmpfs 不会自动创建此节点
  systemd.tmpfiles.rules = [ "c /dev/rfkill 0644 root root - 10:242" ];

  # 引导使用冻结 boot.img 里的 busybox initrd（ABL 装不下 26.11 的 systemd initrd），
  # 本闭包的 initrd 仅是占位，不会被引导用到
  boot.extraModulePackages = lib.mkForce [ ];
  boot.kernelModules = lib.mkForce [ ];
  boot.initrd.kernelModules = lib.mkForce [
    "qcom-refgen-regulator"
    "cec"
    "drm_display_helper"
    "drm_dp_aux_bus"
    "drm_exec"
    "drm_gpuvm"
    "gpu-sched"
    "mdt_loader"
    "ubwc_config"
    "msm"
    "panel-xiaomi-venus-k2"
    "dm-mod"
  ];

  lantian.harden = {
    "venus-net-watch".enable = "network";
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
