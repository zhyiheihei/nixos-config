{
  lib,
  nixpkgsPath,
  ...
}:
# Armbian SC8280XP "vendor" branch, copied verbatim from the Radxa Q8B board
# config (config/boards/radxa-dragon-q8b.conf) and family
# (config/sources/families/sc8280xp.conf):
#   KERNELSOURCE = https://github.com/radxa/kernel.git
#   KERNELBRANCH = branch:linux-7.0.11
#   KERNEL_MAJOR_MINOR = 7.0
#   LINUXCONFIG = linux-sc8280xp-vendor.config
# The generated .config and its Nix attrset are vendored here from
# config/kernel/linux-sc8280xp-vendor.config so the build does not depend on a
# live armbian/build checkout.
let
  crossPkgs = import nixpkgsPath {
    localSystem = "x86_64-linux";
    crossSystem = lib.systems.examples.aarch64-multiplatform;
    config = { };
    overlays = [ ];
  };

  modDirVersion = "7.0.11";

  vendorKernelConfig = ./sc8280xp_vendor_config;
  vendorKernelConfigOptions = import ./sc8280xp_vendor_config.nix;
in
(crossPkgs.linuxManualConfig {
  inherit modDirVersion;
  version = "${modDirVersion}-armbian";
  extraMeta.branch = "linux-7.0.11";
  src = crossPkgs.fetchFromGitHub {
    owner = "radxa";
    repo = "kernel";
    # Pinned to the tip of linux-7.0.11 at bring-up time, matching the
    # armbian vendor branch the board config references.
    rev = "4a7a039590c7185ed9c53453b163806311799eed";
    hash = "sha256-6MBrxmNUTSxq5f+LWXQvbViLNsSA3do1SOgXcAUOSOk=";
  };
  configfile = vendorKernelConfig;
  config = vendorKernelConfigOptions;
  kernelPatches = [ ];
}).overrideAttrs (old: {
  requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
  # Match gnull/nixos-rk3588's vendor.nix dodge: the Armbian extlinux/grub
  # menu labels truncate long derivation names, so shorten this one to "k".
  name = "k";
  # nixpkgs linuxManualConfig runs `make oldconfig`, which prompts for every
  # option absent from the vendored armbian config and stalls on EOF. Expand
  # the fragment with `olddefconfig` first so missing options take their
  # defaults silently, then `oldconfig` has nothing left to ask. This mirrors
  # what the armbian build framework does when expanding the shipped config
  # fragment.
  configurePhase = builtins.replaceStrings
    [
      ''      make "''${makeFlags[@]}" oldconfig''
    ]
    [
      ''      make "''${makeFlags[@]}" olddefconfig && make "''${makeFlags[@]}" oldconfig''
    ]
    (old.configurePhase or "");
})