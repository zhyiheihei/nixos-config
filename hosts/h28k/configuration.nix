{ lib, ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ./dhcp.nix
    ./ddns.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/client-components/multicast-dns.nix
    ../../nixos/optional-apps/miniupnpd.nix
  ];

  # Author's router recipe: LAN clients may open their own port mappings
  # through the DHCP WAN.
  services.miniupnpd = {
    externalInterface = "eth1";
    internalIPs = [ "eth0" ];
  };

  # While staging at home this board sits on the home LAN (same subnet as the
  # home router), but it declares its own site interconnect (h28k-lan), so the
  # fleet-generated ZeroTier `try` list has no hint for the home router
  # (interconnectIPv4For only matches within the same interconnect) and the
  # two nodes never activate a direct path (both stay paths=[] via the PLANET
  # roots only). Mirror the module's try-list derivation, but treat the home
  # router as reachable by its home-lan IP. Remove together with the host.nix
  # hostname override after relocating to the remote site.
  services.zerotierone.localConf.virtual = lib.mkForce
    (lib.mapAttrs'
      (k: host:
        let
          interconnectIPv4 =
            if host.interconnect.name != null && host.interconnect.IPv4 != null
                && (host.interconnect.name == "home-lan" || host.hostname == "router.zhyi.xin")
            then host.interconnect.IPv4
            else null;
        in
          lib.nameValuePair host.zerotier {
            try =
              (lib.optionals (interconnectIPv4 != null) [ "${interconnectIPv4}/9993" ])
              ++ (lib.optionals (host.public.IPv4 != null) [ "${host.public.IPv4}/9993" ])
              ++ (lib.optionals (host.public.IPv6 != null) [ "${host.public.IPv6}/9993" ])
              ++ (lib.optionals (host.public.IPv6Alt != null) [ "${host.public.IPv6Alt}/9993" ]);
          })
      (lib.filterAttrs (n: v: v.zerotier != null) LT.otherHosts));

  networking.networkmanager.enable = lib.mkForce false;

  # Fix stable MAC addresses. The RK3528 GMAC reads its address from the
  # board DT (stable across boots), but the PCIe RTL8111H has no programmed
  # EEPROM MAC and would otherwise get a different address per image or
  # machine-id, breaking DHCP identity and IP stability. Pin both NICs to
  # fixed locally-administered addresses so DHCP reservations and firewall
  # rules keep working across reflashes.
  systemd.network.links = {
    "10-h28k-eth0" = {
      matchConfig.MACAddress = "3e:a8:c4:14:09:23";
      linkConfig.MACAddress = "3e:a8:c4:14:09:23";
    };
    "10-h28k-eth1" = {
      matchConfig.Driver = "r8169";
      linkConfig.MACAddress = "3e:b9:d9:35:dc:2d";
    };
  };

  # One DHCP uplink does not benefit from a userspace MPTCP path manager. It
  # also removes a nonessential failure point from the first router image.
  services.mptcpd.enable = lib.mkForce false;
}
