{
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/minimal.nix
    ./hardware-configuration.nix
  ];

  environment.etc.securetty.text = lib.mkForce ''
    ttyS2
  '';

  networking.wireless = {
    enable = true;
    networks."moli-1004-iot".psk = "88888888";
  };

  systemd.services.wpa_supplicant.serviceConfig = LT.serviceHarden // {
    Restart = "always";

    RestartSec = "5s";

    ProcSubset = lib.mkForce "all";
    SystemCallErrorNumber = lib.mkForce "EPERM";
    PrivateDevices = lib.mkForce false;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
      "AF_PACKET"
    ];
  };

  systemd.services.taishanpi-ssh-host-keys = {
    description = "Generate persistent SSH host keys if missing";
    wantedBy = [ "multi-user.target" ];
    before = [ "sshd.service" ];
    after = [ "nix.mount" ];
    requires = [ "nix.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.openssh ];
    script = ''
      install -d -m 700 /nix/persistent/etc/ssh
      if [ ! -f /nix/persistent/etc/ssh/ssh_host_ed25519_key ]; then
        ssh-keygen -q -t ed25519 -N "" -C "" \
          -f /nix/persistent/etc/ssh/ssh_host_ed25519_key
      fi
      if [ ! -f /nix/persistent/etc/ssh/ssh_host_rsa_key ]; then
        ssh-keygen -q -t rsa -b 4096 -N "" -C "" \
          -f /nix/persistent/etc/ssh/ssh_host_rsa_key
      fi
    '';
  };

  systemd.network.networks."10-taishanpi-wlan" = {
    matchConfig.Name = "wlan0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  systemd.network.networks."09-taishanpi-eth" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
    dhcpV4Config = {
      RouteMetric = 100;
    };
  };

  systemd.network.links."10-taishanpi-eth" = {
    matchConfig.OriginalName = "eth0";
    linkConfig.MACAddress = "3e:b9:d9:35:dc:7f";
  };

  networking.networkmanager.enable = lib.mkForce false;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

}
