{
  pkgs,
  lib,
  config,
  ...
}:

{
  # 条件注入的 steam wrapper：eGPU 在位时行为与公共 prime.nix 的
  # steam-offload 一致（PRIME offload 走 2080 Ti）；不在位时退回核显，
  # 避免 __GLX_VENDOR_LIBRARY_NAME=nvidia 使 bootstrap 的更新 UI 在
  # Xwayland 上创建 GLX context 失败（BadValue / X_GLXCreateContext）
  # 而卡死自更新——2026-09-02 拔 eGPU 后 Steam 一直打不开的根因。
  # /proc/driver/nvidia/version 存在 ⇔ eGPU 在位（模块由 udev 按设备
  # 加载），与 configuration.nix 里 CDI generator 的判定条件相同。
  # 注入脚本在每次运行时判定，重建系统后自动跟随 eGPU 状态，无需热插
  # 后再 rebuild。hiPrio 保证继续覆盖 programs.steam 原入口。
  environment.systemPackages = lib.mkAfter [
    (lib.hiPrio (pkgs.runCommand "steam-override" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      mkdir -p $out/bin
      if [ -f /proc/driver/nvidia/version ]; then
        makeWrapper ${lib.getExe' config.programs.steam.package "steam"} $out/bin/steam \
          --set __NV_PRIME_RENDER_OFFLOAD 1 \
          --set __NV_PRIME_RENDER_OFFLOAD_PROVIDER NVIDIA-G0 \
          --set __GLX_VENDOR_LIBRARY_NAME nvidia \
          --set __VK_LAYER_NV_optimus NVIDIA_only
      else
        makeWrapper ${lib.getExe' config.programs.steam.package "steam"} $out/bin/steam
      fi
    ''))
  ];

  # Enable CUDA
  hardware.graphics.enable = true;

  hardware.nvidia.package = config.boot.kernelPackages.nvidia_x11_beta;
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.nvidiaPersistenced = true;
  hardware.nvidia.prime = {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
  hardware.nvidia.powerManagement.enable = true;
  hardware.nvidia.powerManagement.finegrained = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;

  # nvidia-settings doesn't work with clang lto
  hardware.nvidia.nvidiaSettings = false;

  virtualisation.docker.enableNvidia = true;
  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;
}
