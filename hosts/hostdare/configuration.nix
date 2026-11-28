{
  inputs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    "${inputs.secrets}/nixos-hidden-module/aacd9f37de95f98d"

    ../../nixos/optional-apps/cliproxyapi.nix
    (inputs.secrets + "/cliproxyapi.nix")
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  lantian.nginxVhosts."hostdare.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  lantian.backup.schedule = null;
}
