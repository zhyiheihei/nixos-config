{
  LT,
  lib,
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

  networking.hosts."192.168.2.192" = [ "ml-builder.zhyi.cc" ];

  networking.firewall.allowedTCPPorts = [ LT.port.Attic ];

  # This host is the Attic server itself. Avoid resolving attic.zhyi.cc back to
  # this machine and then depending on the external HTTPS reverse proxy path.
  nix.settings.trusted-substituters = lib.mkForce (
    [
      "http://[::1]:${LT.portStr.Attic}/${LT.nix.attic.cacheName}"
    ]
    ++ lib.filter (url: url != LT.nix.attic.url) LT.constants.nix.substituters
  );
  nix.settings.trusted-public-keys = LT.constants.nix.trusted-public-keys ++ [ LT.nix.attic.publicKey ];

  environment.systemPackages = with pkgs; [
    age
    attic-client
    attic-server
    sops
    ssh-to-age
  ];
}
