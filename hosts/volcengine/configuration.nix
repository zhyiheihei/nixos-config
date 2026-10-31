{ inputs, lib, ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/cliproxyapi.nix
    (inputs.secrets + "/cliproxyapi.nix")
    ../../nixos/optional-apps/dex.nix
    ../../nixos/optional-apps/halo.nix
    ../../nixos/optional-apps/pocket-id.nix
    ../../nixos/optional-apps/vaultwarden.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  lantian.nginxVhosts."bitwarden.zhyi.xin".accessibleBy = lib.mkForce "public";
}
