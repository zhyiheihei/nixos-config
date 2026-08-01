{
  lib,
  nixpkgsPath,
}:
let
  # Instantiate one explicit cross package set. `pkgsCross` is itself a lazy
  # package-set fixed point and recurses when this derivation is exposed as a
  # package of the same Flake.
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
  # Do not use lib.hasInfix as a guard here: recursively scanning this very
  # large generated .config exhausts Nix's evaluator stack.
  opi5pKernelConfig = builtins.toFile "rk35xx-vendor-opi5p-config" (
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
  # Keep gnull's tested Armbian vendor-kernel packaging intact and replace
  # only the two configuration choices needed by this host.
  linuxManualConfig =
    args:
    crossPkgs.linuxManualConfig (
      args
      // {
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
      }
    );
}).overrideAttrs
  (old: {
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
    patches = (old.patches or [ ]) ++ [ ../../nixos/hardware/orangepi-5-plus/vendor-fan-curve.patch ];
  })
