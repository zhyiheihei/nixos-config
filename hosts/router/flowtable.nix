{
  lib,
  pkgs,
  ...
}:
let
  nft = "${lib.getExe' pkgs.nftables "nft"}";
  flowtableScript = pkgs.writeShellScript "router-flowtable" ''
    set -eu
    i=0
    while [ ! -e /sys/class/net/br-lan ] || [ ! -e /sys/class/net/ppp0 ]; do
      sleep 1
      i=$((i + 1))
      if [ "$i" -ge 120 ]; then
        echo "router-flowtable: br-lan/ppp0 not up after 120s" >&2
        exit 1
      fi
    done

    delete_flow_rules() {
      handles=$(
        ${nft} -a list chain inet lantian FILTER_FORWARD |
          grep 'flow add @f' |
          sed -n 's/.*# handle \([0-9][0-9]*\).*/\1/p' || true
      )
      for handle in $handles; do
        ${nft} delete rule inet lantian FILTER_FORWARD handle "$handle"
      done
    }

    rebuild=0
    if ! ${nft} list flowtable inet lantian f >/dev/null 2>&1; then
      rebuild=1
    elif ! ${nft} list flowtable inet lantian f | grep -q ppp0; then
      # PPPoE redial recreates ppp0; a stale flowtable binding must be rebuilt.
      rebuild=1
    fi

    if [ "$rebuild" -eq 1 ]; then
      delete_flow_rules
      if ${nft} list flowtable inet lantian f >/dev/null 2>&1; then
        ${nft} delete flowtable inet lantian f
      fi
      ${nft} -f /etc/nftables/flowtable.nft
      # Offload WAN traffic only.  Hairpin (br-lan -> br-lan) flows measured
      # 184k -> 83k sender retransmits when excluded from the flowtable at
      # 2.3G, while throughput stayed at 2.28 Gbit/s.
      ${nft} insert rule inet lantian FILTER_FORWARD ct state { established, related } iifname "ppp0" flow add @f
      ${nft} insert rule inet lantian FILTER_FORWARD ct state { established, related } iifname "br-lan" oifname != "br-lan" flow add @f
    else
      # Remove the obsolete generic rule, then reassert the two scoped rules.
      obsolete=$(
        ${nft} -a list chain inet lantian FILTER_FORWARD |
          grep 'flow add @f' |
          grep -v 'iifname' |
          sed -n 's/.*# handle \([0-9][0-9]*\).*/\1/p' || true
      )
      for handle in $obsolete; do
        ${nft} delete rule inet lantian FILTER_FORWARD handle "$handle"
      done
      if ! ${nft} list chain inet lantian FILTER_FORWARD | grep -q 'iifname "ppp0" flow add @f'; then
        ${nft} insert rule inet lantian FILTER_FORWARD ct state { established, related } iifname "ppp0" flow add @f
      fi
      if ! ${nft} list chain inet lantian FILTER_FORWARD | grep -q 'iifname "br-lan" oifname != "br-lan" flow add @f'; then
        ${nft} insert rule inet lantian FILTER_FORWARD ct state { established, related } iifname "br-lan" oifname != "br-lan" flow add @f
      fi
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
    # nftables restarts flush the table; the periodic check service restores
    # the fast path within a minute, and restarting with pppd-wan covers
    # PPPoE redial.
    partOf = [
      "nftables.service"
      "pppd-wan.service"
    ];
    path = [
      pkgs.gnugrep
      pkgs.gnused
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = flowtableScript;
      TimeoutStartSec = "150";
      Restart = "on-failure";
      RestartSec = "5";
    };
  };

  # nftables reloads flush the table and PPPoE redials recreate ppp0; the
  # idempotent script re-adds the flowtable and scoped forward rules on a
  # short timer.
  systemd.timers.router-flowtable-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/1";
      Persistent = false;
    };
  };

  systemd.services.router-flowtable-check = {
    description = "Reassert nftables flowtable after reloads or PPPoE redial";
    after = [ "nftables.service" ];
    path = [
      pkgs.gnugrep
      pkgs.gnused
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = flowtableScript;
    };
  };
}
