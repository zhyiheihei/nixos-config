{
  pkgs,
  ...
}:
let
  metricsDir = "/var/lib/node-exporter-textfile";
  qualityScript = pkgs.writeShellScript "router-quality" ''
    set -eu
    out=${metricsDir}/router-quality.prom
    tmp=$(mktemp .router-quality.XXXXXX)
    trap 'rm -f "$tmp"' EXIT
    {
      echo "# HELP router_quality_ping_rtt_ms End-to-end ICMP RTT to public targets."
      echo "# TYPE router_quality_ping_rtt_ms gauge"
      echo "# HELP router_quality_ping_loss_percent End-to-end ICMP loss to public targets."
      echo "# TYPE router_quality_ping_loss_percent gauge"
      echo "# HELP router_quality_dns_query_ms DNS query time to public resolvers."
      echo "# TYPE router_quality_dns_query_ms gauge"
      echo "# HELP router_quality_netdev_rx_missed_errors NIC RX missed errors."
      echo "# TYPE router_quality_netdev_rx_missed_errors gauge"
      echo "# HELP router_quality_netdev_rx_dropped NIC RX dropped packets."
      echo "# TYPE router_quality_netdev_rx_dropped gauge"
      echo "# HELP router_quality_netdev_tx_dropped NIC TX dropped packets."
      echo "# TYPE router_quality_netdev_tx_dropped gauge"

      for target in 223.5.5.5 119.29.29.29; do
        out_ping=$(ping -c 5 -q -W 1 "$target" 2>/dev/null | tail -3)
        loss=$(printf '%s\n' "$out_ping" | sed -n 's/.* \([0-9][0-9.]*\)% packet loss.*/\1/p' | head -1)
        avg=$(printf '%s\n' "$out_ping" | sed -n 's/.*= \([0-9][0-9.]*\)\/[0-9.]*\/[0-9.]*\/[0-9.]*/\1/p' | head -1)
        [ -n "$loss" ] && echo "router_quality_ping_loss_percent{target=\"$target\"} $loss"
        [ -n "$avg" ] && echo "router_quality_ping_rtt_ms{target=\"$target\"} $avg"
      done

      for resolver in 223.5.5.5 119.29.29.29; do
        q=$(dig +time=2 +tries=1 +noall +stats @$resolver baidu.com 2>/dev/null | sed -n 's/.*Query time: \([0-9][0-9]*\) msec.*/\1/p' | head -1)
        [ -n "$q" ] && echo "router_quality_dns_query_ms{resolver=\"$resolver\"} $q"
      done

      for dev in eth0 eth1; do
        for metric in rx_missed_errors rx_dropped tx_dropped; do
          path=/sys/class/net/$dev/statistics/$metric
          if [ -r "$path" ]; then
            value=$(cat "$path")
            echo "router_quality_netdev_''${metric}{device=\"$dev\"} $value"
          fi
        done
      done
    } > "$tmp"
    chmod 0644 "$tmp"
    mv "$tmp" "$out"
    trap - EXIT
  '';
in
{
  systemd.tmpfiles.settings.router-quality.${metricsDir}.d = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  systemd.services.router-quality-check = {
    description = "Export router public quality and NIC drop metrics";
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.bind
      pkgs.coreutils
      pkgs.gnused
      pkgs.iputils
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = qualityScript;
      Restart = "on-failure";
      RestartSec = "30";
    };
  };

  systemd.timers.router-quality-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "60s";
      OnUnitActiveSec = "60s";
      Unit = "router-quality-check.service";
    };
  };
}
