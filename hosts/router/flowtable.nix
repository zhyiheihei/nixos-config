{
  lib,
  pkgs,
  ...
}:
let
  nft = "${lib.getExe' pkgs.nftables "nft"}";
  flowtableScript = pkgs.writeShellScript "router-flowtable" ''
    set -eu

    wan_rule='ct state { established, related } iifname "ppp0" flow add @f'
    lan_rule='ct state { established, related } iifname "br-lan" oifname "ppp0" flow add @f'

    delete_flow_rules() {
      filter=$1
      handles=$(
        ${nft} -a list chain inet lantian FILTER_FORWARD |
          grep 'flow add @f' |
          grep "$filter" |
          sed -n 's/.*# handle \([0-9][0-9]*\).*/\1/p' || true
      )
      for handle in $handles; do
        ${nft} delete rule inet lantian FILTER_FORWARD handle "$handle"
      done
    }

    ensure_flow_rule() {
      pattern=$1
      rule=$2
      if ! ${nft} list chain inet lantian FILTER_FORWARD | grep -Fq "$pattern"; then
        ${nft} insert rule inet lantian FILTER_FORWARD $rule comment "router-flowtable"
      fi
    }

    i=0
    while [ ! -e /sys/class/net/br-lan ] || [ ! -e /sys/class/net/ppp0 ]; do
      sleep 1
      i=$((i + 1))
      if [ "$i" -ge 120 ]; then
        echo "router-flowtable: br-lan/ppp0 not up after 120s" >&2
        exit 1
      fi
    done

    rebuild=0
    if ! ${nft} list flowtable inet lantian f >/dev/null 2>&1; then
      rebuild=1
    elif ! ${nft} list flowtable inet lantian f | grep -q ppp0; then
      # PPPoE redial recreates ppp0; a stale flowtable binding must be rebuilt.
      rebuild=1
    fi

    if [ "$rebuild" -eq 1 ]; then
      delete_flow_rules 'flow add @f'
      if ${nft} list flowtable inet lantian f >/dev/null 2>&1; then
        ${nft} delete flowtable inet lantian f
      fi
      ${nft} -f /etc/nftables/flowtable.nft
      ensure_flow_rule 'iifname "ppp0" flow add @f' "$wan_rule"
      ensure_flow_rule 'iifname "br-lan" oifname "ppp0" flow add @f' "$lan_rule"
    else
      # One-time migration: drop unowned flow-add rules, then reassert ours.
      unowned=$(
        ${nft} -a list chain inet lantian FILTER_FORWARD |
          grep 'flow add @f' |
          grep -v 'router-flowtable' |
          sed -n 's/.*# handle \([0-9][0-9]*\).*/\1/p' || true
      )
      for handle in $unowned; do
        ${nft} delete rule inet lantian FILTER_FORWARD handle "$handle"
      done
      delete_flow_rules 'router-flowtable'
      ensure_flow_rule 'iifname "ppp0" flow add @f' "$wan_rule"
      ensure_flow_rule 'iifname "br-lan" oifname "ppp0" flow add @f' "$lan_rule"
    fi
  '';
in
{
  # nftables.service loads the main ruleset before network interfaces exist,
  # and the flowtable needs real netdevs.  Upstream NixOS issue #141802
  # endorses adding flow offload with a separate service after interfaces are
  # up; its failure is non-critical.  Requires the new kernel with
  # NF_FLOW_TABLE support after a staged boot.  Only WAN (ppp0) flows are
  # offloaded; hairpin flows stay on the normal netfilter path because the
  # measured retransmit benefit is documented in docs/research/10.  Note that
  # offloaded flows bypass the rest of FILTER_FORWARD, so policy that can
  # change after the first packet must live in pre-forward hooks.
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
      TimeoutStartSec = "150";
      ExecStart = flowtableScript;
    };
  };
}
