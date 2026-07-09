{
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/attic.nix
    # ../../nixos/optional-apps/attic-watch-store.nix
    ../../nixos/optional-apps/hydra

    ./hardware-configuration.nix
  ];

  systemd.network.networks.ens18 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "ens18";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.firewall.allowedTCPPorts = [ LT.port.Attic ];

  environment.systemPackages = with pkgs; [
    age
    attic-client
    attic-server
    sops
    ssh-to-age
  ];
}
