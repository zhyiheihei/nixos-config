{
  LT,
  config,
  ...
}:
{
  assertions = [
    {
      assertion = config.lantian.jellyfinRockchip.soc == "rk3588";
      message = "handbrake-rockchip.nix currently supports only RK3588";
    }
  ];

  # Experimental HandBrake fork with native RKMPP/RGA integration.  Keep it
  # host-local instead of replacing the generic HandBrake package or module:
  # upstream HandBrake does not provide an RKMPP backend, and the existing
  # NVIDIA service must remain reproducible on non-Rockchip hosts.
  virtualisation.oci-containers.containers.handbrake = {
    image = "docker.io/emcd39/handbrake-rk3588:latest";
    labels."io.containers.autoupdate" = "registry";
    ports = [ "127.0.0.1:${LT.portStr.HandBrake}:5800" ];
    environment = {
      TZ = config.time.timeZone;
      DISPLAY_WIDTH = "1920";
      DISPLAY_HEIGHT = "900";
      LANG = "zh_CN.UTF-8";
      LANGUAGE = "zh_CN:zh";
      LC_ALL = "zh_CN.UTF-8";
      KEEP_APP_RUNNING = "1";
      CLEAN_TMP_DIR = "1";
      UMASK = "002";
      TAKE_CONFIG_OWNERSHIP = "1";
      # Match the fork's verified compose configuration for the first trial.
      # The container is privileged because RKMPP also opens dma-heap and DRM
      # nodes dynamically; its HTTP listener remains bound to localhost.
      USER_ID = "0";
      GROUP_ID = "0";
    };
    volumes = [
      "/nix/persistent/var/lib/handbrake-rk3588/config:/config"
      "/mnt/storage/handbrake-server/storage:/storage"
      "/mnt/storage/handbrake-server/storage:/watch"
      "/mnt/storage/handbrake-server/output:/output"
    ];
    devices = [
      "/dev/dri:/dev/dri"
      "/dev/mpp_service:/dev/mpp_service"
      "/dev/rga:/dev/rga"
      "/dev/dma_heap:/dev/dma_heap"
    ];
    extraOptions = [
      "--ipc=host"
      "--privileged"
    ];
  };

  systemd.services.podman-handbrake = {
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "mnt-storage.mount"
    ];
    requires = [ "mnt-storage.mount" ];
  };

  systemd.tmpfiles.settings.handbrake-rockchip = {
    "/nix/persistent/var/lib/handbrake-rk3588/config"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    "/mnt/storage/handbrake-server"."d" = {
      mode = "0775";
      user = "1000";
      group = "1000";
    };
    "/mnt/storage/handbrake-server/storage"."d" = {
      mode = "0775";
      user = "1000";
      group = "1000";
    };
    "/mnt/storage/handbrake-server/output"."d" = {
      mode = "0775";
      user = "1000";
      group = "1000";
    };
  };

  # 跨机 -backend 回源 vhost 已撤除（上游无此惯例），直连走本文件主 vhost。
}
