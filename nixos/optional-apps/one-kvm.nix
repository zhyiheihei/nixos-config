{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  cfg = config.lantian.one-kvm;
in
{
  # One-KVM（Rust 版）IP-KVM，silentwind0/one-kvm 官方容器镜像。
  # 依赖主机侧先就位的硬件链路：
  #  - HDMI RX：DTS patch 启用 hdmirx_ctrler（vendor-hdmirx.patch，内核驱动
  #    CONFIG_VIDEO_ROCKCHIP_HDMIRX=y 已内置），容器内以 /dev/video* 采集。
  #  - HID/MSD：Type-C OTG（usbdrd_dwc3_0）切 device 模式后经 configfs 模拟；
  #    容器挂 /dev 与 /sys 并 privileged，gadget 由容器内 one-kvm 自行创建。
  options.lantian.one-kvm = {
    enable = lib.mkEnableOption "the One-KVM IP-KVM container (RK3588 HDMI RX + OTG HID)";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/one-kvm";
      description = "Host directory bind-mounted to /etc/one-kvm (config db + MSD images)";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-one-kvm" = {
      "${cfg.dataDir}"."d" = {
        mode = "755";
        user = "root";
        group = "root";
      };
    };

    # usbdrd_dwc3_0 的 DT dr_mode 为 "otg"（dual-role + usb-role-switch），
    # 开机默认 host。one-kvm 的 OTG gadget 需要 device 模式：经 usb_role
    # 接口切换；容器内写该 sysfs 节点即可，无需 host 侧服务。

    virtualisation.oci-containers.containers.one-kvm = {
      # full 镜像含 ttyd/gostc/easytier 扩展；仅需主程序可换 silentwind0/one-kvm。
      # 镜像名必须全限定：NixOS 的 podman 无 unqualified-search registries，
      # short-name 会直接 pull 失败。
      image = "docker.io/silentwind0/one-kvm:latest";
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      environment = {
        TZ = config.time.timeZone;
      };
      volumes = [
        "${cfg.dataDir}:/etc/one-kvm"
        # OTG gadget（configfs）+ USB role switch 都在 /sys 下
        "/sys:/sys"
        # /dev/video*（HDMI RX）、/dev/snd、/dev/dri、/dev/hidg*、gadget UDC
        "/dev:/dev"
        # 官方 compose 未挂 /lib/modules，但 gadget 依赖的 libcomposite 等
        # 均为内核内建（=y），无需加载模块。
      ];
      extraOptions = [
        # Web(8420)/RTSP(8554)/RustDesk 等端口由程序自身配置，host 网络
        # （Web 端口按 One-KVM 文档设为 8420，端口登记 OneKVM）
        "--network=host"
        "--privileged"
      ];
    };

    systemd.services.podman-one-kvm = {
      # HDMI RX 设备节点需在内核枚举后出现（hdmirx probe 较慢）
      serviceConfig.ExecStartPre = lib.mkBefore [
        (pkgs.writeShellScript "one-kvm-wait-video" ''
          # 等 hdmirx 的 video 节点就绪（最多 60s），没有也不阻塞——设备可能未接
          timeout=60
          while [ "$timeout" -gt 0 ]; do
            # rk_hdmirx 通常是唯一带 video capture 能力的平台节点
            if ls /dev/video* >/dev/null 2>&1; then
              break
            fi
            sleep 2
            timeout=$((timeout - 2))
          done
        '')
      ];
    };

    # KVM Web UI：主机私有域名，OAuth（Dex）保护。容器 host 网络直听 8420。
    lantian.nginxVhosts."kvm.${config.networking.hostName}.zhyi.xin" = {
      locations = {
        "/" = {
          enableOAuth = true;
          proxyPass = "http://127.0.0.1:${LT.portStr.OneKVM}";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
    };
  };
}