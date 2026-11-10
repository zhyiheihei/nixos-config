{
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # fleet 的 impermanence 把 / 设成 tmpfs；venus 的 userdata 分区（ext4, LABEL=nixos）挂 /nix
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  swapDevices = [ ];
}
