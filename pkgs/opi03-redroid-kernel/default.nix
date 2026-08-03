{
  lib,
  nixpkgsPath,
  ...
}:
let
  # Keep every compiler process native on ml-builder while producing an
  # aarch64 kernel.  This package is intentionally isolated from the patched
  # perSystem package fixed point, matching the OPI5P/ROCK 5C kernel boundary.
  crossPkgs = import nixpkgsPath {
    localSystem = "x86_64-linux";
    crossSystem = lib.systems.examples.aarch64-multiplatform;
    config = { };
    overlays = [ ];
  };

  vendorSource = crossPkgs.fetchFromGitHub {
    owner = "orangepi-xunlong";
    repo = "linux-orangepi";
    rev = "9ab7a758149d3c9b721878a0c18b3f9c5d6c93e6";
    hash = "sha256-9vPjjbSA6Knec7GyZ20sO3FZKhxRRzaK/vwGXhbOyD0=";
  };

  # This complete config is generated from Orange Pi's H618 Android defconfig
  # plus the audited NixOS/Podman/reDroid host delta in generate-config.sh.
  # Keeping the resolved result as a literal path avoids an import-from-
  # derivation during evaluation on macOS or non-builder hosts.
  opi03Config = ./kernel-config;
  opi03ConfigText = builtins.readFile opi03Config;

  # linuxManualConfig uses this attribute set to decide whether to emit the
  # modules/dev outputs.  Parse the final generated text explicitly because a
  # explicit attribute set also makes the module/dev output decision obvious.
  opi03ConfigAttrs = lib.listToAttrs (
    lib.concatMap (
      line:
      let
        match = builtins.match "(CONFIG_[^=]+)=([ym])" line;
      in
      lib.optional (match != null) {
        name = builtins.elemAt match 0;
        value = builtins.elemAt match 1;
      }
    ) (lib.splitString "\n" opi03ConfigText)
  );
in
(crossPkgs.linuxManualConfig {
  pname = "linux-opi03-h618-redroid";
  version = "5.4.125";
  modDirVersion = "5.4.125";
  src = vendorSource;
  configfile = opi03Config;
  config = opi03ConfigAttrs;
  extraMeta = {
    description = "Orange Pi H618 vendor kernel for NixOS and reDroid 12";
    platforms = [ "aarch64-linux" ];
  };
}).overrideAttrs
  (old: {
    # The original 5.4 Zero 3 DTS was imported once and left its RGMII RX
    # delay at zero.  Orange Pi's later 6.1 DTS, upstream Linux and the public
    # p3 Android 12 board config all carry the missing board timing in their
    # respective binding syntax.  Keep the compatibility conversion local to
    # this board-specific kernel package.
    patches = (old.patches or [ ]) ++ [ ./orangepi-zero3-board-fixes.patch ];
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
    passthru = (old.passthru or { }) // {
      inherit vendorSource;
    };
  })
