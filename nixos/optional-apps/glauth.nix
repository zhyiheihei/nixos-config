{
  pkgs,
  LT,
  config,
  inputs,
  lib,
  ...
}:
let
  glauthUsers = import (inputs.secrets + "/glauth-users.nix");

  hexdump = lib.stringAsChars (
    c: lib.fixedWidthString 2 "0" (lib.toHexString (lib.strings.charToInt c))
  );

  cfg = pkgs.writeText "glauth.cfg" ''
    [ldap]
      enabled = true
      listen = "[::]:${LT.portStr.LDAP}"

    [ldaps]
      enabled = true
      listen = "[::]:${LT.portStr.LDAPS}"
      cert = "${LT.nginx.getSSLCert "lets-encrypt-zhyi.xin-ecc"}"
      key = "${LT.nginx.getSSLKey "lets-encrypt-zhyi.xin-ecc"}"

    [[backends]]
      datastore = "config"
      baseDN = "dc=zhyi,dc=xin"

    [behaviors]
      IgnoreCapabilities = false
      LimitFailedBinds = false

    [[users]]
      name = "zhyi"
      givenname = "Zh"
      sn = "Yi"
      mail = "${glauthUsers.zhyi.mail}"
      uidnumber = 1000
      primarygroup = 100
      passbcrypt = "${hexdump glauthUsers.zhyi.passBcrypt}"
      [[users.customattributes]]
        displayName = ["Zh Yi"]

    [[users]]
      name = "serviceuser"
      mail = "serviceuser@example.com"
      uidnumber = 60000
      primarygroup = 60000
      passbcrypt = "${hexdump glauthUsers.serviceuser.passBcrypt}"
      [[users.capabilities]]
        action = "search"
        object = "*"
      [[users.customattributes]]
        displayName = ["Service User"]

    [[groups]]
      name = "admin"
      gidnumber = 100

    [[groups]]
      name = "svcaccts"
      gidnumber = 60000

    [api]
      enabled = false
  '';

  netns = config.lantian.netns.glauth;
in
{
  lantian.netns.glauth = {
    ipSuffix = "38";
    announcedIPv4 = [
      "198.19.0.38"
      "10.127.10.38"
    ];
    announcedIPv6 = [
      "fdd8:1938:4e88:3712::389"
      "fd10:127:10:2547::389"
    ];
    birdBindTo = [ "glauth.service" ];
  };

  systemd.services.glauth = netns.bind {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = LT.serviceHarden // {
      Type = "simple";
      Restart = "always";
      RestartSec = "3";
      ExecStart = "${lib.getExe pkgs.nur-xddxdd.glauth} -c ${cfg}";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    };
  };
}
