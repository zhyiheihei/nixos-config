{
  lib,
  nixpkgsPath,
  ...
}:
let
  # Match the proven OPI5P packaging model: keep the cross package set outside
  # NixOS module evaluation so exposing this kernel cannot recurse through the
  # per-system patched package set.
  crossPkgs = import nixpkgsPath {
    localSystem = "x86_64-linux";
    crossSystem = lib.systems.examples.aarch64-multiplatform;
    config = { };
    overlays = [ ];
  };
  rk3588NixSource = crossPkgs.fetchFromGitHub {
    owner = "gnull";
    repo = "nixos-rk3588";
    rev = "2a1add82960dda2e0d203051dcf1ae4c1bc8452c";
    hash = "sha256-nHNgt6Kkn+rFrJW2vFDsTLd7DfYlZWQgCPyk67L2q/E=";
  };
  vendorKernelConfig = builtins.readFile (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config");
  vendorKernelConfigOptions = import (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config.nix");
  rock5cKernelConfig = builtins.toFile "rk35xx-vendor-rock5c-config" (
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
(crossPkgs.callPackage (rk3588NixSource + "/pkgs/kernel/vendor.nix") {
  # vendor.nix consumes linuxManualConfig while constructing the kernel. A
  # later derivation override does not replace its already-generated config.
  linuxManualConfig =
    args:
    crossPkgs.linuxManualConfig (
      args
      // {
        configfile = rock5cKernelConfig;
        config =
          builtins.removeAttrs vendorKernelConfigOptions [
            "CONFIG_ARM64_VA_BITS_48"
            "CONFIG_ARM64_VA_BITS"
          ]
          // {
            CONFIG_ARM64_VA_BITS_39 = "y";
            CONFIG_ARM64_VA_BITS = "9";
            # MPTCP is built into this vendor kernel, so IPv6 must be built in
            # as well for the IPv6 MPTCP protocol family to be registered.
            CONFIG_IPV6 = "y";
          };
      }
    );
}).overrideAttrs
  (old: {
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
    patches = (old.patches or [ ]) ++ [ ../../nixos/hardware/rock-5c/vendor-fan-curve.patch ];
  })
