{
  lib,
  pkgs,
  ...
}:
let
  rpsScript = pkgs.writeShellScript "router-rps" ''
    set -eu

    # One RX queue per core: the r8125 driver exposes eth0-0..3 / eth1-0..3
    # MSI-X vectors, but irqbalance packs several of them onto one CPU and
    # that caused NIC rx_missed/retransmits under multi-flow load.  Pin each
    # queue IRQ to its matching CPU instead and disable irqbalance below.
    for dev in eth0 eth1; do
      for q in 0 1 2 3; do
        irq=$(
          awk -v dev="$dev" -v q="$q" \
            '$NF == dev "-" q { sub(":", "", $1); print $1 }' \
            /proc/interrupts | head -1
        )
        if [ -n "$irq" ]; then
          echo "$q" > "/proc/irq/$irq/smp_affinity_list"
        fi
      done
    done

    for dev in eth0 eth1; do
      for q in /sys/class/net/$dev/queues/rx-*; do
        if [ -e "$q/rps_cpus" ]; then
          echo f > "$q/rps_cpus"
          echo 8192 > "$q/rps_flow_cnt"
        fi
      done
      for q in /sys/class/net/$dev/queues/tx-*; do
        if [ -e "$q/xps_cpus" ]; then
          echo f > "$q/xps_cpus"
        fi
      done
    done
  '';
in
{
  # Follow the OpenWrt NanoPi R5C high-throughput recipe that is backed by
  # community measurements: raise device/socket buffers and spread every RX
  # queue across all four RK3568 cores.  The r8125 override opens 4 RX queues;
  # the RPS flow tables are sized for 4 queues x 8192 entries.  BBR is already
  # enabled globally by nixos/minimal-components/networking.nix.  The larger
  # NAPI budget was measured to eliminate WAN rx_missed under qBittorrent load
  # (600/20000 -> 1338 missed per 808k packets; 1200/30000 -> 0 missed).
  boot.kernel.sysctl = {
    "net.core.netdev_budget" = 1200;
    "net.core.netdev_budget_usecs" = 30000;
    "net.core.flow_limit_table_len" = 16384;
    "net.core.netdev_max_backlog" = 5000;
    "net.core.optmem_max" = 131072;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.rps_sock_flow_entries" = 32768;
  };

  # The public default enables irqbalance on multi-core hosts, but its queue
  # placement hurt RTL8125 multi-queue performance on this board.  Keep the
  # network IRQs pinned by router-rps instead.
  services.irqbalance.enable = lib.mkForce false;

  systemd.services.router-rps = {
    description = "Spread RTL8125 RX queues across all router cores";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-networkd.service"
      "sys-subsystem-net-devices-eth0.device"
      "sys-subsystem-net-devices-eth1.device"
    ];
    wants = [
      "sys-subsystem-net-devices-eth0.device"
      "sys-subsystem-net-devices-eth1.device"
    ];
    path = [
      pkgs.coreutils
      pkgs.gawk
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = rpsScript;
      Restart = "on-failure";
      RestartSec = "5";
    };
  };
}
