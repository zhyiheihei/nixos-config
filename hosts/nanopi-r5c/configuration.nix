{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/minimal.nix
    ../../nixos/hardware/disable-watchdog.nix
    ./hardware-configuration.nix
  ];

  boot.tmp.cleanOnBoot = true;

  networking = {
    firewall.allowedTCPPorts = [
      22
      2222
    ];
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network = {
    enable = true;

    # Installation/rescue image: keep DHCP but also give each physical port a
    # fixed address outside the router's DHCP pool. This guarantees SSH access
    # without a serial console regardless of which port is connected.
    networks = {
      "20-r5c-eth0" = {
        matchConfig.Name = "eth0";
        address = [ "192.168.0.98/24" ];
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
          MulticastDNS = true;
        };
      };
      "20-r5c-eth1" = {
        matchConfig.Name = "eth1";
        address = [ "192.168.0.99/24" ];
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
          MulticastDNS = true;
        };
      };
    };
  };

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    openssh.ports = lib.mkForce [
      22
      2222
    ];
  };

  environment.systemPackages = with pkgs; [
    ethtool
    pciutils
    usbutils
  ];

  # Generate a unique persistent host key on first boot. No private key is
  # embedded in the world-readable Nix store or image derivation.
  systemd.services.r5c-generate-ssh-host-key = {
    description = "Generate the persistent R5C SSH host key";
    wantedBy = [ "sshd.service" ];
    before = [ "sshd.service" ];
    unitConfig.ConditionPathExists = "!/nix/persistent/etc/ssh/ssh_host_ed25519_key";
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 /nix/persistent/etc/ssh
      ${lib.getExe' pkgs.openssh "ssh-keygen"} -q -t ed25519 -N "" \
        -f /nix/persistent/etc/ssh/ssh_host_ed25519_key
    '';
  };
}
