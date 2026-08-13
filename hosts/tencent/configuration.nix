{ ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;

  # Korea has no entry in the shared yggdrasil regionMappings
  # (nixos/common-apps/yggdrasil/default.nix); peer the closest regions
  # instead of editing the public module.
  services.yggdrasil.regions = [
    "japan"
    "singapore"
  ];
}
