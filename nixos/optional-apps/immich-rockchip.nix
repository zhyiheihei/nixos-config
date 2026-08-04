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
    volumes = [ "${config.lantian.immich.storage}-ml-cache:/cache" ];
    devices = [
      # RKNPU 驱动设备（Armbian vendor kernel，CONFIG_ROCKCHIP_RKNPU=y）
      "/dev/rknpu:/dev/rknpu"
    ];
    extraOptions = [
      # host 网络：监听 3003，immich-server 固定连 http://localhost:3003
      "--network=host"
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
