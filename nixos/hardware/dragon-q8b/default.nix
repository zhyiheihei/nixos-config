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
    # btrfs is CONFIG_BTRFS_FS=m (module), not built-in — without it in
    # initrd, blkid cannot read btrfs superblocks and by-uuid devices never
    # appear, causing root mount timeout.
    #
    # TC956x 2.5GbE + r8152 USB NIC are also modules (=m); they load via
    # auxiliary/PCI/USB bus auto-matching but only if present in initrd.
    initrd.availableKernelModules = lib.mkForce [
      "btrfs"
      "dwmac_tc956x"
      "gpio_tc956x"
      "r8152"
    ];
    initrd.kernelModules = lib.mkForce [
      "btrfs"
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
