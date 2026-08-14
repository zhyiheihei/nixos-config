{
  pkgs,
  ...
}:
{
  services.miniupnpd = {
    enable = true;
    upnp = true;
    natpmp = true;
  };

  # The nixpkgs module picks the nftables backend automatically when
  # networking.nftables is enabled (the router's case), but does not put
  # `nft` on the daemon's PATH: every mapping add fails with "Failed to
  # add NAT-PMP ..." even though the table/chains are correctly hooked.
  # The old iptables ExecStartPre/ExecStopPost overrides were removed
  # because they reference the plain build's scripts and cannot work on
  # an nftables-only system.
  systemd.services.miniupnpd = {
    path = [ pkgs.nftables ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "3";
    };
  };
}
