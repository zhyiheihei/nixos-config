{
  pkgs,
  lib,
  LT,
  config,
  ...
}:
{
  options.lantian.enablePodman = lib.mkOption {
    type = lib.types.bool;
    default = config.virtualisation.oci-containers.containers != { } || LT.this.hasTag LT.tags.client;
  };

  config = lib.mkIf config.lantian.enablePodman {
    environment.systemPackages = config.virtualisation.podman.extraPackages;

    virtualisation.containers.containersConf.settings = {
      network.firewall_driver = "nftables";
      engine.cdi_spec_dirs = [
        "/etc/cdi"
        "/var/run/cdi"
      ];
    };

    virtualisation.podman = {
      enable = true;
      autoPrune = {
        enable = true;
        flags = [ "-af" ];
      };
      # Podman DNS conflicts with my authoritative resolver
      defaultNetwork.settings.dns_enabled = false;
      dockerCompat = true;
      dockerSocket.enable = true;

      extraPackages = [ pkgs.nftables ];
      # ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [ pkgs.gvisor ];
    };

    systemd.services = {
      podman-auto-update.enable = true;
    }
    // (lib.mapAttrs' (
      k: v:
      lib.nameValuePair "podman-${k}" {
        environment.TMPDIR = "/var/cache/podman-download";
      }
    ) config.virtualisation.oci-containers.containers);

    systemd.timers.podman-auto-update = {
      enable = true;
      wantedBy = [ "timers.target" ];
    };

    systemd.tmpfiles.settings = {
      podman-download = {
        "/var/cache/podman-download"."d" = {
          mode = "755";
          user = "root";
          group = "root";
        };
      };
    };
    users.users.zhyi.extraGroups = [ "podman" ];

    virtualisation.oci-containers.backend = "podman";

    # CN 区域设备自动配置镜像加速源，避免直连不可达。
    # hub.tencent.zhyi.xin 为自建 hubproxy（LTNET 隧道），daocloud 兜底。
    # hubproxy 对 docker.io 用根路径（/v2/library/alpine），对其余上游用
    # 「上游前缀」路径（/v2/ghcr.io/<repo>），因此非 Docker Hub 的 mirror
    # location 必须携带上游前缀（hub.tencent.zhyi.xin/ghcr.io 等），
    # 由容器栈完成路径改写。支持的源经逐个探测确认：ghcr.io / quay.io /
    # registry.k8s.io / gcr.io 可达；mcr.microsoft.com / lscr.io /
    # nvcr.io 不支持。
    environment.etc."containers/registries.conf.d/99-mirrors.conf" = lib.mkIf (LT.this.city.country == "CN") {
      text =
        ''
          [[registry]]
          location = "docker.io"

          [[registry.mirror]]
          location = "hub.tencent.zhyi.xin"

          [[registry.mirror]]
          location = "docker.m.daocloud.io"
        ''
        + lib.concatMapStrings (upstream: ''
          [[registry]]
          location = "${upstream}"

          [[registry.mirror]]
          location = "hub.tencent.zhyi.xin/${upstream}"
        '') [
          "ghcr.io"
          "quay.io"
          "registry.k8s.io"
          "gcr.io"
        ];
    };
  };
}
