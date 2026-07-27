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

    # Give the two PCIe RTL8125 NICs stable names using their observed paths.
    links = {
      "10-r5c-lan" = {
        matchConfig.Path = "pci-0001:11:00.0";
        linkConfig.Name = "lan1";
      };
      "10-r5c-wan" = {
        matchConfig.Path = "pci-0002:21:00.0";
        linkConfig.Name = "wan1";
      };
    };

    # Blind first boot: request DHCP on every Ethernet interface so either
    # physical port can provide SSH access.
    networks."20-wired-dhcp" = {
      matchConfig.Type = "ether";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        MulticastDNS = true;
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
