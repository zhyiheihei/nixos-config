# reDroid 安卓容器（RK3588，CNflysky lineage-20 镜像）公共模块。
#
# 平台要求：RK3588 + Armbian vendor kernel 的 Mali CSF/Bifrost 驱动
# （/dev/mali0 由宿主侧硬件配置提供）。镜像刻意放在 immutable closure
# 之外，由 Podman 运行时拉取，Android 状态落在持久盘。
{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
{
  options.lantian.redroid = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the reDroid Android container.";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/cnflysky/redroid-rk3588:lineage-20";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/redroid-rk3588-lineage20";
      description = "Persistent Android state directory (bind-mounted to /data).";
    };
    # 等待该接口拿到 interconnect IPv4 后再起容器（各主机网卡命名不同，
    # opi5p 经 udev link 固定为 lan0）。
    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "lan0";
    };
  };

  config = lib.mkIf config.lantian.redroid.enable (
    lib.mkMerge [
      {
        # Android's bpfloader requires this to remain writable/enabled. The common
        # hardening policy sets it to the irreversible value 1, which cannot be
        # changed back until reboot and makes every official reDroid image shut down.
        # Keep ADB bound to the LAN address; do not expose this host publicly.
        boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

        virtualisation.oci-containers.containers.redroid = {
          image = config.lantian.redroid.image;
          labels."io.containers.autoupdate" = "registry";
          privileged = true;
          ports = [ "${LT.this.interconnect.IPv4}:5555:5555" ];
          volumes = [
            "${config.lantian.redroid.dataDir}:/data"
          ];
          cmd = [
            # Define a portrait-native panel, then rotate it below. Android will
            # still render at 1280x720, but SystemUI uses its landscape side-navbar
            # layout instead of treating landscape as the natural rotation.
            "androidboot.redroid_width=720"
            "androidboot.redroid_height=1280"
            "androidboot.redroid_fps=60"
            # CNflysky exposes ADB through the container Ethernet interface. Declare
            # both settings explicitly instead of relying on image defaults, so a
            # container/image refresh cannot silently disable network ADB. The host
            # port remains bound only to the home-LAN address above.
            "androidboot.redroid_adbd_bind_eth0=1"
            "ro.adb.secure=0"
            # reDroid is connected through the container's Ethernet interface.
            # Some Android applications only start large downloads on Wi-Fi, so use
            # the image's supported Fake WiFi compatibility layer.
            "androidboot.redroid_fake_wifi=1"
            # Enable the Kitsune Magisk integration bundled with this image.
            "androidboot.redroid_magisk=1"
            # Match the upstream compose example instead of advertising a TV or
            # embedded-device product class to applications.
            "ro.build.characteristics=default"
          ];
        };

        systemd.tmpfiles.settings.redroid."${config.lantian.redroid.dataDir}"."d" = {
          mode = "0700";
          user = "root";
          group = "root";
        };

        systemd.services.podman-redroid = {
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          # 镜像加速域名直连，其余按集群统一出站代理。
          environment = LT.proxyEnvironment // {
            NO_PROXY = "${LT.proxyBypass},docker.m.daocloud.io";
          };
          preStart = ''
            for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
              if ${pkgs.iproute2}/bin/ip -4 address show ${config.lantian.redroid.lanInterface} \
                | ${pkgs.gnugrep}/bin/grep -qF "inet ${LT.this.interconnect.IPv4}/24"; then
                break
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done

            if ! ${pkgs.iproute2}/bin/ip -4 address show ${config.lantian.redroid.lanInterface} \
              | ${pkgs.gnugrep}/bin/grep -qF "inet ${LT.this.interconnect.IPv4}/24"; then
              echo "LAN address ${LT.this.interconnect.IPv4} is unavailable" >&2
              exit 1
            fi

            if ! test -c /dev/mali0; then
              echo "Armbian Mali CSF device /dev/mali0 is unavailable" >&2
              exit 1
            fi
          '';
        };

        systemd.services.redroid-landscape-navigation = {
          description = "Configure reDroid display, navigation, and application networking";
          wantedBy = [ "multi-user.target" ];
          after = [ "podman-redroid.service" ];
          requires = [ "podman-redroid.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = 5;
          };
          script = ''
            for attempt in $(${pkgs.coreutils}/bin/seq 1 90); do
              if ${pkgs.podman}/bin/podman exec redroid getprop sys.boot_completed \
                | ${pkgs.gnugrep}/bin/grep -qx 1; then
                ${pkgs.podman}/bin/podman exec redroid wm size reset
                ${pkgs.podman}/bin/podman exec redroid wm user-rotation lock 1
                # The image enables Android's restricted networking mode by default.
                # It blocks ordinary application UIDs (including TapTap) even while
                # the container, DNS, and Android's validated default network work.
                ${pkgs.podman}/bin/podman exec redroid settings put global restricted_networking_mode 0
                exit 0
              fi
              ${pkgs.coreutils}/bin/sleep 2
            done

            echo "reDroid did not finish booting within 180 seconds" >&2
            exit 1
          '';
        };
      }
    ]
  );
}
