# 雷神加速器（SteamDeck 插件渠道守护）的 NixOS 模块。
# 上游 Husky0c/leigod-plugin-linux 用 shell watchdog 每 5 秒拉活两个进程，
# NixOS 下 systemd Restart 本身就是监督器，故直接拆成两个常驻 unit：
#   leigod-daemon           主加速程序（tun 分流、iptables/ipset 规则）
#   leigod-upgrade-monitor  官方升级监控（同一二进制不同角色参数）
#
# 关键适配点（均有官方安装脚本/二进制 strings 佐证）：
# - 二进制内硬编码状态根路径 /home/leigod：符号链接到 /var/lib/leigod；
# - 服务端仅向 SteamDeck 设备下发配置：BindReadOnlyPaths 伪装 DMI 与
#   os-release（内容镜像上游 fake_product_name/fake_os-release）；
# - 启动前创建 dummy wlan0 并克隆真实网卡 MAC 作为设备标识。
{
  lib,
  pkgs,
  ...
}:
let
  leigod = pkgs.callPackage ../../pkgs/leigod-accelerator { };

  stateDir = "/var/lib/leigod";

  fakeProductName = pkgs.writeText "leigod-fake-product-name" ''
    Jupiter
  '';
  fakeOsRelease = pkgs.writeText "leigod-fake-os-release" ''
    NAME="SteamOS"
    ID=steamos
    ID_LIKE=arch
    BUILD_ID=20260420.100
    PRETTY_NAME="SteamOS"
    VERSION_ID=3.6
  '';

  # 与上游 steamdeck_acc_monitor.sh 一致的设备标识逻辑：优先取无线/
  # 有线物理网卡的 MAC，取不到时退回 /etc/machine-id 派生的固定值。
  mkDummyWlan0 = pkgs.writers.writeDash "leigod-mk-dummy-wlan0" ''
    if ip link show wlan0 >/dev/null 2>&1; then exit 0; fi
    REAL_MAC=""
    for addr in /sys/class/net/wl*/address /sys/class/net/en*/address; do
      [ -f "$addr" ] || continue
      REAL_MAC=$(cat "$addr")
      [ -n "$REAL_MAC" ] && break
    done
    if [ -z "$REAL_MAC" ]; then
      REAL_MAC="02:$(md5sum /etc/machine-id | head -c 10 | sed 's/\(..\)/\1:/g;s/:$//')"
    fi
    ip link add wlan0 type dummy
    ip link set wlan0 address "$REAL_MAC"
    ip link set wlan0 up
  '';

  # 静态配置模板只落盘一次：其后官方升级/绑定流程可能改写它们
  setupState = ''
    ln -sfn ${stateDir} /home/leigod
    mkdir -p ${stateDir}/config
    for f in ${leigod}/share/leigod/config/*; do
      cp -n "$f" ${stateDir}/config/ || true
    done
    chmod -R u+w ${stateDir}/config
  '';

  mkLeigodUnit =
    {
      description,
      exec,
      pre ? setupState,
    }:
    {
      inherit description;
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # acc-gw 运行期按名字调用这些工具建立分流与探测
      path = [
        pkgs.iptables
        pkgs.ipset
        pkgs.curl
      ];

      serviceConfig = {
        Type = "simple";
        ExecStart = exec;
        Restart = "always";
        RestartSec = "3";
        KillMode = "control-group";
        WorkingDirectory = stateDir;
        StateDirectory = "leigod";
        BindReadOnlyPaths = [
          "${fakeProductName}:/sys/class/dmi/id/product_name"
          "${fakeOsRelease}:/etc/os-release"
        ];
      };

      preStart = pre;
    };
in
{
  boot.kernelModules = [ "dummy" "tun" ];

  environment.systemPackages = [ leigod ];

  systemd.services.leigod-daemon = mkLeigodUnit {
    description = "Leigod accelerator daemon";
    exec = "${leigod}/share/leigod/acc-gw.router.amd64 -r daemon -m tun -p 5588";
    pre = ''
      ${mkDummyWlan0}
      ${setupState}
    '';
  };

  systemd.services.leigod-upgrade-monitor = mkLeigodUnit {
    description = "Leigod accelerator upgrade monitor";
    exec = "${leigod}/share/leigod/acc_upgrade_monitor -r upgrade";
  };
}
