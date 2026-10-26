{ lib, ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ./dex.nix
    ../../nixos/optional-apps/halo.nix
    ../../nixos/optional-apps/pocket-id.nix
    ../../nixos/optional-apps/vaultwarden.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  sops.secrets.dex-oauth-proxy-secret = {
    owner = "dex";
    group = "dex";
  };

  lantian.nginxVhosts."bitwarden.zhyi.xin".accessibleBy = lib.mkForce "public";
}
