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
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = lib.mkForce [ ];
    # This force replaces the repository-wide module list, so retain the
    # modules required by the standard server role.  The SC8280XP board DTB is
    # passed by the UEFI firmware and the TC956x 2.5GbE pairs load from the
    # auxiliary bus automatically, so no board-specific driver is listed here.
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
