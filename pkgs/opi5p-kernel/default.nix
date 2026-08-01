{
  lib,
  pkgsCross,
}:
let
  crossPkgs = pkgsCross.aarch64-multiplatform;
  rk3588NixSource = crossPkgs.fetchFromGitHub {
    owner = "gnull";
    repo = "nixos-rk3588";
    rev = "2a1add82960dda2e0d203051dcf1ae4c1bc8452c";
    hash = "sha256-nHNgt6Kkn+rFrJW2vFDsTLd7DfYlZWQgCPyk67L2q/E=";
  };
  vendorKernelConfig = builtins.readFile (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config");
  vendorKernelConfigOptions = import (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config.nix");
  opi5pKernelConfig =
    assert lib.hasInfix "# CONFIG_ARM64_VA_BITS_39 is not set" vendorKernelConfig;
    assert lib.hasInfix "CONFIG_ARM64_VA_BITS_48=y" vendorKernelConfig;
    assert lib.hasInfix "CONFIG_ARM64_VA_BITS=48" vendorKernelConfig;
    assert lib.hasInfix "CONFIG_IPV6=m" vendorKernelConfig;
    builtins.toFile "rk35xx-vendor-opi5p-config" (
      builtins.replaceStrings
        [
          "# CONFIG_ARM64_VA_BITS_39 is not set"
          "CONFIG_ARM64_VA_BITS_48=y"
          "CONFIG_ARM64_VA_BITS=48"
          "CONFIG_IPV6=m"
        ]
        [
          "CONFIG_ARM64_VA_BITS_39=y"
          "# CONFIG_ARM64_VA_BITS_48 is not set"
          "CONFIG_ARM64_VA_BITS=39"
          "CONFIG_IPV6=y"
        ]
        vendorKernelConfig
    );
in
(crossPkgs.linuxManualConfig {
  modDirVersion = "6.1.115";
  version = "6.1.115-armbian";
  extraMeta.branch = "rk-6.1-rkr5.1";
  src = crossPkgs.fetchFromGitHub {
    owner = "armbian";
    repo = "linux-rockchip";
    rev = "b908c7339f51eddcfe8402cd15d1e1f8f4e67c29";
    hash = "sha256-70wGP16SJHs7I8HklhNdrJbWzfvcgJCupgfOq81e1U8=";
  };
  kernelPatches = [ ];
  configfile = opi5pKernelConfig;
  config =
    builtins.removeAttrs vendorKernelConfigOptions [
      "CONFIG_ARM64_VA_BITS_48"
      "CONFIG_ARM64_VA_BITS"
    ]
    // {
      CONFIG_ARM64_VA_BITS_39 = "y";
      CONFIG_ARM64_VA_BITS = "9";
      CONFIG_IPV6 = "y";
    };
}).overrideAttrs
  (old: {
    name = "k";
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ crossPkgs.ubootTools ];
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
    patches = (old.patches or [ ]) ++ [ ../../nixos/hardware/orangepi-5-plus/vendor-fan-curve.patch ];
    postPatch = ''
      sed -i "drivers/gpu/arm/bifrost/csf/mali_kbase_csf_firmware.c" \
        -e "s:drivers/gpu/arm/bifrost/mali_csffw.bin:$src/drivers/gpu/arm/bifrost/mali_csffw.bin:"
    ''
    + "\n"
    + (old.postPatch or "");
  })
