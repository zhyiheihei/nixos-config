{
  LT,
  config,
  lib,
  ...
}:
{
  imports = [ ./immich-rknn-worker.nix ];

  # Rockchip RK3588 专用：immich-machine-learning 改用官方 -rknn 容器镜像
  # （https://immich.app/docs/features/ml-hardware-acceleration#rknn）。
  # 避免在 aarch64 上 nix 构建 scipy/onnxruntime 依赖链（f2py SIGABRT 问题）。
  services.immich.machine-learning.enable = lib.mkForce false;

  # 清空 nix 版 ML 服务定义（含 immich.nix 还原后的 PrivateDevices 覆盖），
  # 避免生成无 ExecStart 的坏单元；RKNN 推理交给下方容器。
  systemd.services.immich-machine-learning = lib.mkForce { };

  # 共享 RKNN worker：容器、设备树挂载、/dev/dri 与代理统一由
  # immich-rknn-worker.nix 提供，opi5p 和 rock5c 各按内存配置线程数。
  lantian.immichRknnWorker = {
    enable = true;
    cacheDir = "${config.lantian.immich.storage}-ml-cache";
    threads = 3;
  };
}
