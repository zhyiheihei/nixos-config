{
  lib,
  config,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ../../nixos/optional-apps/ncps-client.nix
    # 2026-10-21 随上游停用，用户指示重新启用（fork 偏移：上游无 palworld 消费主机）。
    ../../nixos/optional-apps/palworld.nix

    ./hardware-configuration.nix
    ./media-automation.nix
  ];

  # 摘除 server 标签后 backup 默认关闭，显式启用（同 ml-laptop 惯例）。
  lantian.backup.enable = true;

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  systemd.network.networks."10-chromebox-lan" = {
    matchConfig.Name = "eno0";
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

  # 通用策略禁用全局 wait-online，NFS 挂载依赖按接口实例。
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@eno0.service" ];

  # palworld-exporter 1.3.1 的存档自动发现与新版 Palworld 的 backup/ 子目录布局
  # 不兼容（glob 到两个 Level.sav 后报 No GameUserSettings.ini 退出），且 9877
  # 无 Prometheus 抓取方，禁用避免崩溃重启循环；服务器本体不受影响。
  systemd.services.palworld-exporter.enable = false;

  # 上游 treewide RestartSec（b1383d16）会让 ensure-service-restart 断言
  # 拒绝 RestartSec < 3s 或缺省的 Restart 服务；palworld 仅 chromebox 导入，
  # 上游无消费主机故未在其列，主机级补齐避免偏离共享模块。
  systemd.services.palworld.serviceConfig.RestartSec = "5s";

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };
}
