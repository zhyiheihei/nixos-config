{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # 与 opi5p / nanopi-r5c 同款布局："/" 用 tmpfs，"/nix" 是独立 btrfs（label NIXOS_NIX）。
  # 这两条与 fleet 的 impermanence 模块完全同构，因此这里不需要任何 mkForce。
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=755"
      "nodev"
      "nosuid"
      "relatime"
      "size=80%"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/NIXOS_NIX";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  swapDevices = [ ];
}
