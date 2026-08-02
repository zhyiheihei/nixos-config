{ lib, ... }:
{
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [ "eth0/192.168.30.1" ];
        dhcp-socket-type = "raw";
      };
      lease-database = {
        name = "/var/lib/kea/dhcp4.leases";
        persist = true;
        type = "memfile";
      };

      rebind-timer = 3600 * 6;
      renew-timer = 3600 * 3;
      valid-lifetime = 3600 * 12;

      subnet4 = [
        {
          id = 30;
          subnet = "192.168.30.0/24";
          interface = "eth0";
          pools = [ { pool = "192.168.30.100 - 192.168.30.249"; } ];
          option-data = [
            {
              name = "routers";
              data = "192.168.30.1";
            }
            {
              name = "domain-name-servers";
              data = "192.168.30.1";
            }
          ];
        }
      ];
    };
  };

  systemd.services.kea-dhcp4-server.serviceConfig = {
    Restart = lib.mkForce "always";
    RestartSec = 3;
  };
}
