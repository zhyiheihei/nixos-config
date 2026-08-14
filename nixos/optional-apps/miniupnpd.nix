{ ... }:
{
  services.miniupnpd = {
    enable = true;
    upnp = true;
    natpmp = true;
  };

  # The nixpkgs module picks the nftables backend automatically when
  # networking.nftables is enabled (the router's case). The old iptables
  # ExecStartPre/ExecStopPost overrides referenced the plain build's
  # iptables_init.sh, which fails on an nftables-only system and would
  # break the service on any restart; the module's own nftables setup
  # (table inet miniupnpd, hooked nat chains) handles rule insertion.
  systemd.services.miniupnpd.serviceConfig = {
    Restart = "always";
    RestartSec = "3";
  };
}
