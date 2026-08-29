{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lantian.vfio;
in
{
  options.lantian.vfio = {
    ids = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    blacklistedModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    isolcpus = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    disableFramebuffer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = {
    boot.kernelModules = [
      "vfio-pci"
    ];
    # IOMMU/ACS 参数仅在真正配置了直通设备时注入：pcie_acs_override 会在
    # 下游端口（含雷电桥）伪造 ACS、改写 PCIe 事务路由，对雷电 eGPU 等非
    # 直通场景是有害的（实测导致 Xid 79 空间掉卡）。ids 为空的主机不应背
    # 这些参数。
    boot.kernelParams = lib.optionals (cfg.ids != [ ]) [
      "intel_iommu=on"
      "iommu=pt"
      "amd_iommu=on"
      "pcie_acs_override=downstream,multifunction"
    ]
    ++ lib.optionals (cfg.isolcpus != null) [
      "isolcpus=${cfg.isolcpus}"
      "nohz_full=${cfg.isolcpus}"
      "rcu_nocbs=${cfg.isolcpus}"
    ]
    ++ lib.optionals cfg.disableFramebuffer [
      # https://forum.proxmox.com/threads/problem-with-gpu-passthrough.55918/post-478351
      "video=simplefb:off"
      "video=vesafb:off"
      "video=efifb:off"
      "initcall_blacklist=sysfb_init"
    ];
    boot.extraModprobeConfig = ''
      softdep drm pre: vfio-pci
      softdep nvidia pre: vfio-pci
      options vfio-pci disable_denylist=1 ids=${lib.concatStringsSep "," cfg.ids} ${lib.optionalString cfg.disableFramebuffer "disable_vga=1"}
    ''
    + (lib.concatMapStringsSep "\n" (n: ''
      blacklist ${n}
      install ${n} ${lib.getExe' pkgs.coreutils "true"}
    '') cfg.blacklistedModules);
  };
}
