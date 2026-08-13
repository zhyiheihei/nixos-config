{
  inputs,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/uni-api.nix

    "${inputs.secrets}/nixos-hidden-module/aacd9f37de95f98d"
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  lantian.nginxVhosts."hostdare.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;
}
