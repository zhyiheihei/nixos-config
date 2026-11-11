{ config, lib, ... }:
{
  options.lantian.gpuUnlockTargets = lib.mkOption {
    type = lib.types.str;
    default = "all";
  };

  config = {
    boot.kernelParams = [ "gpu_unlock.targets=${config.lantian.gpuUnlockTargets}" ];

    # The unlock must finish before the NVIDIA driver binds the GPU.
    boot.initrd.kernelModules = [ "gpu_unlock" ];
    boot.extraModulePackages = [ config.boot.kernelPackages.gpu-unlock ];
    hardware.firmware = [ config.boot.kernelPackages.gpu-unlock.firmware ];
  };
}
