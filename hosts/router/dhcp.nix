{
  lib,
  inputs,
  LT,
  ...
}:
let

  reservations = import (inputs.secrets + "/dhcp-reservations.nix");
in
{

  users.users.kea = {
    isSystemUser = true;
    group = "kea";
  };
  users.groups.kea = { };

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
          reservations = reservations.home;
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

  systemd.services.kea-dhcp4-server.serviceConfig = LT.networkToolHarden // {
    Restart = lib.mkForce "always";
    RestartSec = 3;
    DynamicUser = lib.mkForce false;
    PrivateUsers = false;
    BindPaths = [
      "/var/lib/kea"
      "/run/kea"
    ];
    BindReadOnlyPaths = [
      "/etc/kea"
    ];
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
      "AF_PACKET"
    ];
  };
  environment.etc."kea/dhcp4-server.conf".mode = "0444";
  lantian.harden.kea-dhcp4-server = true;

  services.kea.dhcp6 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [ "br-lan/fc00:192:168::1" ];
      };
      lease-database = {
        name = "/var/lib/kea/dhcp6.leases";
        persist = true;
        type = "memfile";
      };

      rebind-timer = 3600 * 6;
      renew-timer = 3600 * 3;
      valid-lifetime = 3600 * 12;

      subnet6 = [
        {
          id = 1;
          subnet = "fc00:192:168::/64";
          interface = "br-lan";
          pools = [ { pool = "fc00:192:168::ff00 - fc00:192:168::ffff"; } ];
          option-data = [
            {
              name = "dns-servers";
              data = "fc00:192:168::1";
            }
          ];
        }
      ];
    };
  };

  systemd.services.kea-dhcp6-server.serviceConfig = LT.networkToolHarden // {
    Restart = lib.mkForce "always";
    RestartSec = 3;
    DynamicUser = lib.mkForce false;
    PrivateUsers = false;
    BindPaths = [
      "/var/lib/kea"
      "/run/kea"
    ];
    BindReadOnlyPaths = [
      "/etc/kea"
    ];
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
      "AF_PACKET"
    ];
  };
  environment.etc."kea/dhcp6-server.conf".mode = "0444";
  lantian.harden.kea-dhcp6-server = true;
}
