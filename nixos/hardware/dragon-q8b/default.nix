{
  lib,
  modulesPath,
  self,
  pkgs,
  ...
}:
let
  sc8280xpKernel = self.packages.x86_64-linux.sc8280xp-kernel;

  radxaFirmware = pkgs.runCommand "radxa-firmware-sc8280xp" {} ''
    mkdir -p $out/lib/firmware/qcom/sc8280xp/radxa/dragon-q8b
    cp -r ${pkgs.fetchFromGitHub {
      owner = "radxa-pkg";
      repo = "radxa-firmware";
      rev = "e1761009df008adfd62c77f2c5584e3067449013";
      hash = "sha256-W7SLEGWRhnnSO0Rk1v002BNymId22imEWaYKBAOgs6Y=";
    }}/radxa-firmware-sc8280xp/lib/firmware/* $out/lib/firmware/
    # Audioreach topology, required by qcom-apm (dmesg otherwise:
    # "tplg firmware loading qcom/sc8280xp/SC8280XP-Radxa-Dragon-Q8B-tplg.bin failed -2").
    # Not shipped in radxa-pkg/radxa-firmware nor upstream linux-firmware;
    # extracted from the official Ubuntu image (radxa-dragon-midstream noble r5).
    # Copied to both paths (no symlink): the firmware zstd-compression hook
    # renames files to .zst and breaks relative symlinks pointing at them.
    cp ${./firmware/SC8280XP-Radxa-Dragon-Q8B-tplg.bin} \
      $out/lib/firmware/qcom/sc8280xp/radxa/dragon-q8b/SC8280XP-Radxa-Dragon-Q8B-tplg.bin
    cp ${./firmware/SC8280XP-Radxa-Dragon-Q8B-tplg.bin} \
      $out/lib/firmware/qcom/sc8280xp/SC8280XP-Radxa-Dragon-Q8B-tplg.bin
  '';
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    # btrfs is CONFIG_BTRFS_FS=y (built-in) in the Radxa defconfig — no .ko
    # needed in initrd.  TC956x 2.5GbE + r8152 USB NIC are modules (=m).
    # DRM_MSM is =m (module) so GPU driver loads after initrd is mounted,
    # allowing firmware_class.path to find ZAP shader firmware.
    initrd.availableKernelModules = lib.mkForce [
      "dwmac_tc956x"
      "gpio_tc956x"
      "r8152"
      "msm"
    ];
    initrd.kernelModules = lib.mkForce [
      "dwmac_tc956x"
      "gpio_tc956x"
      "r8152"
      "msm"
    ];
    # This force replaces the repository-wide module list, so retain the
    # modules required by the standard server role.
    kernelModules = lib.mkForce [
      "tls"
      "wireguard"
    ];
    # The generic out-of-tree modules use native ARM build tools and cannot
    # build against this x86_64 cross-built vendor kernel.
    extraModulePackages = lib.mkForce [ ];
  };

  fileSystems."/run/nullfs".enable = lib.mkForce false;

  hardware.firmware = [ radxaFirmware ];

  lantian.kernel = lib.mkForce sc8280xpKernel;
}
