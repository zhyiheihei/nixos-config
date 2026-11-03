{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/ncps-client.nix
    ./hardware-configuration.nix
  ];

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

  boot.kernelParams = [
    # Bring-up only: needed to read the DSI host and D-PHY registers over
    # /dev/mem. Remove together with the panel bring-up tools.
    "iomem=relaxed"
  ];

  systemd.tmpfiles.rules = [ "d /var/cache/zones 0755 knot knot -" ];

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

    # Panel bring-up test: a minimal X desktop on the MIPI panel, driven by
    # its own service. Remove together with the panel bring-up tools.
    feh
    imagemagick
    openbox
    xf86-input-libinput
    xorg.xinit
    xorg.xorgserver
    xterm
  ];

  systemd.services.panel-x = {
    description = "Test X server on the MIPI panel";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "panel-x-start" ''
        ${pkgs.imagemagick}/bin/magick -size 1080x1920 gradient:'#1e3a8a'-'#ec4899' /tmp/wall.png
        ${pkgs.xorg.xinit}/bin/xinit /bin/sh -c '
          ${pkgs.feh}/bin/feh --bg-fill /tmp/wall.png
          exec ${pkgs.openbox}/bin/openbox
        ' -- ${pkgs.xorg.xorgserver}/bin/Xorg :0 vt2 -noreset -nolisten tcp \
          -modulepath ${pkgs.xorg.xorgserver}/lib/xorg/modules,${pkgs.xorg.xf86inputlibinput}/lib/xorg/modules
      '';
      ExecStop = "${pkgs.procps}/bin/killall Xorg";
      PrivateDevices = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      UtmpIdentifier = "vt2";
    };
  };

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
      pkgs.kmod
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
      dmesg | grep -iE "mdio|motorcomm|gmac|stmmac|eth[01]|pcf8563|rtc|8852|rtw|sdio|mmc2"
      echo "== sdio"
      for d in /sys/bus/sdio/devices/*; do
        echo "--- $d"
        cat "$d/vendor" "$d/device" "$d/class"
        readlink -f "$d/driver"
      done
      echo "== wifi"
      lsmod | grep -E "8852|cfg80211|mac80211|rfkill"
      sync
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
