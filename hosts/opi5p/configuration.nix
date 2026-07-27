{
  lib,
  pkgs,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/minimal.nix

    ./hardware-configuration.nix
  ];

  # ── Phase 1: Minimal boot validation ──────────────────────────────
  # Only enable what is needed to validate the boot chain, serial
  # console, network, and SSH access.  Do NOT add production services
  # until Phase 4 gates are passed.

  # Temporary SSH key for initial bring-up.  Remove after formal
  # host keys and SOPS are validated.
  users.users.root.openssh.authorizedKeys.keys = [
    # TODO: replace with your actual temporary public key
    # "ssh-ed25519 AAAA... your-key-comment"
  ];

  # Static network configuration for initial LAN access.
  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };

  networking.networkmanager.enable = lib.mkForce false;
}
