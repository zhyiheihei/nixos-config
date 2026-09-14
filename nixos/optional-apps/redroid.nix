# reDroid 安卓容器（Qualcomm SC8280XP / Dragon Q8B，官方 12.0.0 镜像）公共模块。
#
# 平台要求：宿主内核带 binderfs/ashmem（pkgs/sc8280xp-kernel 已开启），
# DRM msm 提供 /dev/dri/renderD128（Adreno 690，prebuilts Mesa 24.0.8
# 原生支持 freedreno host 硬加速，2026-09-14 实机验证）。
# 镜像放在 immutable closure 之外由 Podman 拉取，Android 状态落持久盘。
{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
{
  options.lantian.redroidSc8280xp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the reDroid Android container (Adreno/freedreno host GPU).";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/redroid/redroid:13.0.0-latest";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/redroid";
      description = "Persistent Android state directory (bind-mounted to /data).";
    };
    # 等待该接口拿到 interconnect IPv4 后再起容器（dragon-q8b 网卡为 eth0）。
    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
    };
  };

  config = lib.mkIf config.lantian.redroidSc8280xp.enable {
    # Android bpfloader requires this; common hardening policy forces it to 1
    # (irreversible until reboot) and kills official reDroid images.
    boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

    virtualisation.oci-containers.containers.redroid = {
      image = config.lantian.redroidSc8280xp.image;
      labels."io.containers.autoupdate" = "registry";
      privileged = true;
      ports = [ "${LT.this.interconnect.IPv4}:5555:5555" ];
      volumes = [
        "${config.lantian.redroidSc8280xp.dataDir}:/data"
        "/dev/dri:/dev/dri"
      ];
      cmd = [
        "androidboot.use_memfd=1"
        "androidboot.redroid_gpu_mode=host"
        "androidboot.redroid_gpu_node=/dev/dri/renderD128"
        "androidboot.redroid_width=720"
        "androidboot.redroid_height=1280"
        "androidboot.redroid_fps=60"
        # ADB exposed through the container Ethernet interface; the host port is
        # bound to the home-LAN address only. Never expose this host publicly.
        "androidboot.redroid_adbd_bind_eth0=1"
        "ro.adb.secure=0"
        # Some Android applications only start large downloads on Wi-Fi.
        "androidboot.redroid_fake_wifi=1"
        "ro.build.characteristics=default"
      ];
    };

    systemd.tmpfiles.settings.redroid."${config.lantian.redroidSc8280xp.dataDir}"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };

    systemd.services.podman-redroid = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = LT.proxyEnvironment // {
        NO_PROXY = "${LT.proxyBypass},docker.m.daocloud.io";
      };
      preStart = ''
        for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
          if ${pkgs.iproute2}/bin/ip -4 address show ${config.lantian.redroidSc8280xp.lanInterface} \
            | ${pkgs.gnugrep}/bin/grep -qF "inet ${LT.this.interconnect.IPv4}/24"; then
            break
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done

        if ! ${pkgs.iproute2}/bin/ip -4 address show ${config.lantian.redroidSc8280xp.lanInterface} \
          | ${pkgs.gnugrep}/bin/grep -qF "inet ${LT.this.interconnect.IPv4}/24"; then
          echo "LAN address ${LT.this.interconnect.IPv4} is unavailable" >&2
          exit 1
        fi

        if ! test -c /dev/dri/renderD128; then
          echo "DRM msm render node /dev/dri/renderD128 is unavailable" >&2
          exit 1
        fi
      '';
    };
  };
}
