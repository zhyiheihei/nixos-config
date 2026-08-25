{
  lib,
  modulesPath,
  self,
  ...
}:
let
  # Keep the cross-built vendor kernel outside NixOS module evaluation, using
  # the same package boundary as the other ARM boards (rock5c, opi5p).  The
  # kernel is a regular x86_64 Flake package that emits aarch64 binaries on
  # ml-builder.
  sc8280xpKernel = self.packages.x86_64-linux.sc8280xp-kernel;
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    # btrfs is CONFIG_BTRFS_FS=y (built-in) in the Radxa defconfig — no .ko
    # needed in initrd.  TC956x 2.5GbE + r8152 USB NIC are modules (=m).
    initrd.availableKernelModules = lib.mkForce [
      "dwmac_tc956x"
      "gpio_tc956x"
      "r8152"
    ];
    initrd.kernelModules = lib.mkForce [
      "dwmac_tc956x"
      "gpio_tc956x"
      "r8152"
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

  lantian.kernel = lib.mkForce sc8280xpKernel;
}
