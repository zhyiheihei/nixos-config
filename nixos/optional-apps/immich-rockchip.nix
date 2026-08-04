{
  LT,
  config,
  lib,
  ...
}:
{
  # Rockchip RK3588 专用：immich-machine-learning 改用官方 -rknn 容器镜像
  # （https://immich.app/docs/features/ml-hardware-acceleration#rknn）。
  # 避免在 aarch64 上 nix 构建 scipy/onnxruntime 依赖链（f2py SIGABRT 问题）。
  services.immich.machine-learning.enable = lib.mkForce false;

  # 清空 nix 版 ML 服务定义（含 immich.nix 还原后的 PrivateDevices 覆盖），
  # 避免生成无 ExecStart 的坏单元；RKNN 推理交给下方容器。
  systemd.services.immich-machine-learning = lib.mkForce { };

  virtualisation.oci-containers.containers.immich-machine-learning-rknn = {
    image = "ghcr.io/immich-app/immich-machine-learning:release-rknn";
    autoStart = true;
    labels."io.containers.autoupdate" = "registry";
    environment = {
      MACHINE_LEARNING_RKNN = "true";
      MACHINE_LEARNING_RKNN_THREADS = "3";
      MACHINE_LEARNING_CACHE_FOLDER = "/cache";
      XDG_CACHE_HOME = "/cache";
      IMMICH_HOST = "0.0.0.0";
      IMMICH_PORT = "3003";
    };
    volumes = [
      "${config.lantian.immich.storage}-ml-cache:/cache"
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

  systemd.tmpfiles.settings = {
    immich-ml-cache = {
      "${config.lantian.immich.storage}-ml-cache"."d" = {
        mode = "755";
        user = "immich";
        group = "immich";
      };
    };
  };
}
