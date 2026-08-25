{
  lib,
  nixpkgsPath,
  ...
}:
# Radxa Dragon Q8B official kernel.  Same radxa/kernel repo as the Armbian
# vendor kernel, but pinned to the commit referenced by the radxa-pkg/
# linux-qcom rsdk packaging repo's submodule, and using the official
# radxa_qcom_7_0_defconfig instead of Armbian's vendored config.
#
# Key advantages over the Armbian vendor config:
#   - CONFIG_IPV6 defaults to y (built-in) → CONFIG_MPTCP_IPV6 auto-enabled
#     → nginx "listen [::]:80 multipath" works
#   - CONFIG_BTRFS_FS=y (built-in) → no btrfs.ko needed in initrd
#   - CONFIG_EFIVAR_FS=y (built-in)
#   - No CONFIG_DEBUG_INFO_BTF (avoids pahole segfault)
let
  crossPkgs = import nixpkgsPath {
    localSystem = "x86_64-linux";
    crossSystem = lib.systems.examples.aarch64-multiplatform;
    config = { };
    overlays = [ ];
  };

  crossStdenv = crossPkgs.gcc14Stdenv;

  modDirVersion = "7.0.11";

  # Board-specific and NixOS-required options not in the Radxa defconfig.
  extraConfigFragment = crossPkgs.writeText "extra.config" ''
    CONFIG_TC956X_PCI=m
    CONFIG_DWMAC_TC956X=m
    CONFIG_GPIO_TC956X=m
    CONFIG_USB_R8152=m
    CONFIG_ARCH_MMAP_RND_BITS_MAX=33
    CONFIG_ARCH_MMAP_RND_BITS_MIN=18
    CONFIG_ARCH_MMAP_RND_COMPAT_BITS_MAX=16
    CONFIG_ARCH_MMAP_RND_COMPAT_BITS_MIN=11
    # dragon-q8b uses Adreno 690, not AMD/NVIDIA GPU; cross-compile fails
    # CONFIG_DRM_AMDGPU is not set
    # CONFIG_DRM_NOUVEAU is not set
    # GCC 14 cross-compile segfaults in dwarf2out.cc with DWARF5 debug info
    # CONFIG_DEBUG_INFO is not set
  '';
in
(crossPkgs.linuxManualConfig {
  stdenv = crossStdenv;
  target = "vmlinuz.efi";
  inherit modDirVersion;
  version = "${modDirVersion}-radxa";
  extraMeta.branch = "linux-7.0.11";
  src = crossPkgs.fetchFromGitHub {
    owner = "radxa";
    repo = "kernel";
    # Pinned to the commit referenced by radxa-pkg/linux-qcom submodule
    # (2026-08-18), the official Radxa kernel for SC8280XP boards.
    rev = "f87cd1e7a6cf9e164ef1a34c846312f9055e3f29";
    hash = "sha256-e6Ic4NJ1H0xLbyezDAvqCFpRg7F9AaQpXZiFpBW+Dmw=";
  };
  # configfile is used by nixpkgs sysctl module to grep ARCH_MMAP_RND_BITS_*
  # and by other modules that inspect the kernel config.  preConfigure generates
  # the real .config via `make radxa_qcom_7_0_defconfig`; this stub only needs to
  # satisfy the grep checks for NixOS-required options.
  configfile = crossPkgs.writeText "stub.config" ''
    CONFIG_ARCH_MMAP_RND_BITS_MAX=33
    CONFIG_ARCH_MMAP_RND_BITS_MIN=18
    CONFIG_ARCH_MMAP_RND_COMPAT_BITS_MAX=16
    CONFIG_ARCH_MMAP_RND_COMPAT_BITS_MIN=11
    CONFIG_BTRFS_FS=y
    CONFIG_MPTCP=y
    CONFIG_MPTCP_IPV6=y
    CONFIG_EFIVAR_FS=y
  '';
  config = {
    CONFIG_MODULES = "y";
    CONFIG_BTRFS_FS = "y";
    CONFIG_EFIVAR_FS = "y";
    CONFIG_DRM_MSM = "y";
    CONFIG_MPTCP = "y";
    CONFIG_MPTCP_IPV6 = "y";
    CONFIG_STMMAC_ETH = "m";
    CONFIG_BLK_DEV_NVME = "y";
    CONFIG_MMC_SDHCI_MSM = "y";
    CONFIG_QCA808X_PHY = "y";
  };
  kernelPatches = [ ];
  features = {
    efiBootStub = true;
  };
}).overrideAttrs (old: {
  requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
  name = "k";
  # postInstall contains `make modules_install` which we need. Only skip
  # the `cp vmlinux $dev/` line since Radxa defconfig doesn't generate vmlinux.
  postInstall = builtins.replaceStrings
    ["cp vmlinux $dev/"]
    ["# cp vmlinux skipped — Radxa defconfig does not generate vmlinux"]
    (old.postInstall or "");
  preConfigure = ''
    export buildRoot="$(pwd)/build"
    mkdir -p "$buildRoot"

    # Expand the official Radxa defconfig (ARCH=arm64 required, otherwise
    # make looks under arch/x86/configs/ on the x86_64 build host)
    make ARCH=arm64 O="$buildRoot" radxa_qcom_7_0_defconfig

    # Append board-specific / NixOS-required config, then re-expand
    cat ${extraConfigFragment} >> "$buildRoot/.config"
    make ARCH=arm64 O="$buildRoot" olddefconfig
  '';
  # preConfigure already expanded the defconfig and produced a complete
  # .config.  Replace the entire configurePhase to avoid linuxManualConfig's
  # default mkdir/cp/oldconfig sequence conflicting with our preConfigure.
  configurePhase = ''
    runHook preConfigure
    runHook postConfigure
  '';
})