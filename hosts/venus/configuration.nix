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
    networks."moli-1004-backup" = {
      pskRaw = "ext:psk_venus";
      # 独立安装那份用 NM 的 wpa-psk(WPA2) 就能连上；这里默认会先用 SAE(WPA3)，
      # AP 直接回 AUTH-REJECT status=1，所以把认证方式钉成纯 WPA2-PSK。
      authProtocols = [ "WPA-PSK" ];
    };
  };
  sops.secrets."venus-wifi-secrets" = {
    sopsFile = inputs.secrets + "/per-host/wifi/venus.yaml";
    key = "wpa-secrets";
    # wpa_supplicant 以 wpa_supplicant 用户运行，默认 root:root 0400 它读不了
    # （journal: "EXT PW FILE: could not open file ... Permission denied"）
    owner = "wpa_supplicant";
    mode = "0400";
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
    wantedBy = [ "sysinit.target" ];
    before = [
      "sysinit.target"
      "systemd-sysusers.service"
      "systemd-tmpfiles-setup.service"
      "getty.target"
      "sshd.service"
      "venus-wifi-power.service"
    ];
    unitConfig.DefaultDependencies = false;
    # /nix 与 /run 由 initrd 挂好并跨 switch-root 继承，不能再等 local-fs.target：
    # 它会让 activate 与 userborn/tmpfiles-setup-dev/local-fs-pre 形成 ordering cycle。
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/nix/var/nix/profiles/system/activate";
    };
  };
  # 90 秒无网即 dd 回滚并重启的看门狗是单机自愈用的；fleet 角色下由 colmena 管回滚，
  # 且其计数器在持久层缺失导致每次开机归零、引导未完成就被重启
  # 引导期临时开启：WiFi 起不来时自动把 boot_b 回滚成可 SSH 的救援系统并重启，
  # 这样取日志/再烧写都不必人工进 fastboot（WiFi 跑通后改回 false）。
  # 内核迭代期开启：WiFi 起不来时 90s 后把 boot_b 刷回救援镜像并重启，
  # 这样新内核实验失败也能自动回到可 SSH（22 端口）的救援系统，不必人工进 fastboot。
  systemd.services.venus-wifi-fallback.enable = lib.mkForce true;

  # 引导使用冻结 boot.img 里的 busybox initrd（ABL 装不下 26.11 的 systemd initrd），
  # 本闭包的 initrd 仅是占位，不会被引导用到
  # 冻结内核缺 zram/dummy：单独编好的模块由板级模块开机 insmod
  # （不能进 boot.extraModulePackages，见 pkgs/venus-extra-modules 说明）
  boot.extraModulePackages = lib.mkForce [ ];
  venus.extraKernelModules = pkgs.venus-extra-modules;
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
