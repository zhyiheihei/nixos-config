{
  config,
  lib,
  LT,
  ...
}:
let
  cfg = config.lantian.immichRknnWorker;
in
{
  options.lantian.immichRknnWorker = {
    enable = lib.mkEnableOption "the shared Immich RKNN ML worker container";
    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/immich-ml-cache";
      description = "Host directory bind-mounted into the container's /cache";
    };
    threads = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "RKNNLite thread pool size per model (memory scales with this)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Distributed Immich ML worker using the official -rknn image. OPI5P keeps
    # the primary worker; immich-server is configured with both URLs in
    # system-config.machineLearning.urls so jobs spread across RKNN nodes.
    virtualisation.oci-containers.containers.immich-machine-learning-rknn = {
      image = "ghcr.io/immich-app/immich-machine-learning:release-rknn";
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      environment = {
        MACHINE_LEARNING_RKNN = "true";
        MACHINE_LEARNING_RKNN_THREADS = builtins.toString cfg.threads;
        MACHINE_LEARNING_CACHE_FOLDER = "/cache";
        XDG_CACHE_HOME = "/cache";
        IMMICH_HOST = "0.0.0.0";
        IMMICH_PORT = "3003";
      };
      volumes = [
        "${cfg.cacheDir}:/cache"
        # Immich 的 RKNN 检测读容器内 /proc/device-tree/compatible（软链到
        # /sys/firmware/devicetree/base）。容器默认看不到该路径，会判定
        # "rknn is not available"；把 host 设备树 bind 到软链目标即可。
        "/sys/firmware/devicetree/base:/sys/firmware/devicetree/base:ro"
      ];
      devices = [
        # Armbian vendor kernel 的 rknpu 0.9.8 驱动注册为 DRM 节点
        # /dev/dri/renderD128，不再是旧版 misc 设备 /dev/rknpu；
        # 官方 hwaccel.ml.yml 的 rknn 段也是挂载 /dev/dri。
        "/dev/dri:/dev/dri"
      ];
      extraOptions = [
        # host 网络：监听 3003，immich-server 固定连 http://localhost:3003
        "--network=host"
        # 官方 rknn 配置同时放宽 system paths/apparmor，否则容器内
        # /sys、/proc 被掩蔽，设备树与 DRM 探测会被拒绝。
        "--security-opt=systempaths=unconfined"
        "--security-opt=apparmor=unconfined"
      ];
    };

    systemd.tmpfiles.settings.immich-ml-cache."${cfg.cacheDir}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };
  };
}
