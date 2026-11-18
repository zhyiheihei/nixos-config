{
  LT,
  ...
}:
{
  services.coturn = {
    enable = true;
    listening-port = LT.port.Stun;
    no-auth = true;
    no-tcp = true;
    no-tls = true;
    no-dtls = true;
    no-cli = true;
    extraConfig = "stun-only";
  };

  systemd.services.coturn.serviceConfig = {
    RestartSec = "5s";
  };

  lantian.harden.coturn = {
    enable = true;
    enableConfinement = false;
  };

  lantian.firewall.zones = {
    LTNET.udpPorts."${LT.portStr.Stun}".type = "local";
  };
}
