{
  lib,
  pkgs,
  ...
}:
let
  nft = "${lib.getExe' pkgs.nftables "nft"}";
  flowtableScript = pkgs.writeShellScript "router-flowtable" ''
    set -eu
    while [ ! -e /sys/class/net/br-lan ] || [ ! -e /sys/class/net/ppp0 ]; do
      sleep 1
    done
    if ! ${nft} list flowtable inet lantian f >/dev/null 2>&1; then
      ${nft} -f /etc/nftables/flowtable.nft
    fi
    if ! ${nft} list chain inet lantian FILTER_FORWARD | grep -q 'flow add @f'; then
      ${nft} insert rule inet lantian FILTER_FORWARD ct state { established, related } flow add @f
    fi
  '';
in
{
  # nftables.service loads the main ruleset before network interfaces exist,
  # and the flowtable needs real netdevs.  Upstream NixOS issue #141802
  # endorses adding flow offload with a separate service after interfaces are
  # up; its failure is non-critical.  Requires the new kernel with
  # NF_FLOW_TABLE support after a staged boot.
  environment.etc."nftables/flowtable.nft".text = ''
    add flowtable inet lantian f {
      hook ingress priority filter
      devices = { ppp0, br-lan }
    }
  '';

  systemd.services.router-flowtable = {
    description = "Enable nftables flowtable fast path after interfaces are up";
    wantedBy = [ "multi-user.target" ];
    after = [
      "nftables.service"
      "systemd-networkd.service"
      "pppd-wan.service"
    ];
    wants = [ "nftables.service" ];
    path = [ pkgs.gnugrep ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = flowtableScript;
      Restart = "on-failure";
      RestartSec = "5";
    };
  };
}
