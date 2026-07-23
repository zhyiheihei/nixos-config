{ lib, ... }:
{
  # Follow the home-router Kea layout.  Infrastructure addresses stay static;
  # ordinary home devices receive addresses only from the .100-.249 pool.
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [ "br-lan/192.168.0.1" ];
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
          id = 1;
          subnet = "192.168.0.0/24";
          interface = "br-lan";
          pools = [ { pool = "192.168.0.100 - 192.168.0.249"; } ];
          option-data = [
            {
              name = "routers";
              data = "192.168.0.1";
            }
            {
              name = "domain-name-servers";
              data = "192.168.0.1";
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
