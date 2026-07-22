{ pkgs, ... }:
{
  systemd.network.networks = {
    # WAN: DHCP from existing router
    eth0 = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = "no";
      };
    };

    # LAN: static gateway for VMs
    eth1 = {
      matchConfig.Name = "eth1";
      address = [ "192.168.0.1/24" ];
      linkConfig.MTUBytes = "9000";
    };
  };

  # Trigger DDNS update when WAN becomes routable
  services.networkd-dispatcher = {
    enable = true;
    rules.trigger-ddns = {
      onState = [ "routable" ];
      script = ''
        #!${pkgs.runtimeShell}
        if [ "$IFACE" = "eth0" ]; then
          echo "Restarting GCore DDNS ..."
          systemctl restart --no-block ddns-gcore.service
        fi
        exit 0
      '';
    };
  };
}
