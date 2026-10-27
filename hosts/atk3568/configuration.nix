{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ./hardware-configuration.nix
  ];

  # The board has no DNS record yet, so deploy over the LAN address while the
  # hostname stays the fleet-wide one used for secrets and the WireGuard mesh.
  deployment.targetHost = lib.mkForce "192.168.0.63";

  # Bring-up image: both RK3568 GMACs are equivalent until the first serial log,
  # so match on the interface name and address the board on the LAN.
  systemd.network.networks."10-atk3568-lan" = {
    matchConfig.Name = "eth*";
    address = [ "192.168.0.63/24" ];
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  networking.networkmanager.enable = lib.mkForce false;

  # Bring-up only: the serial console is the only path into an image whose
  # Ethernet is still being characterised. Remove together with the tools below.
  services.getty.autologinUser = "root";

  environment.systemPackages = with pkgs; [
    ethtool
    i2c-tools
    libgpiod
    mdio-tools
    mmc-utils
    pciutils
    usbutils
  ];

  # The 1.5 Mbaud debug UART drops bytes on multi-line output, so dump the boot
  # state onto the FAT partition instead and read it back with the card in a
  # normal machine.
  systemd.services.atk3568-diag = {
    description = "Dump ATK-DLRK3568 bring-up state to the firmware partition";
    wantedBy = [ "multi-user.target" ];
    after = [
      "boot.mount"
      "local-fs.target"
    ];
    path = [
      pkgs.ethtool
      pkgs.iproute2
      pkgs.util-linux
    ];
    script = ''
      exec > /boot/atk-diag.txt 2>&1
      echo "== ip"
      ip -br a
      echo "== networkctl"
      networkctl status
      echo "== mdio"
      for d in /sys/bus/mdio_bus/devices/*; do
        echo "--- $d"
        cat "$d/phy_id"
        readlink -f "$d/driver"
      done
      echo "== ethtool"
      for i in eth0 eth1; do
        echo "--- $i"
        ethtool "$i"
        ethtool -i "$i"
      done
      echo "== dmesg"
      dmesg | grep -iE "mdio|motorcomm|gmac|stmmac|eth[01]|pcf8563|rtc"
      sync
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
