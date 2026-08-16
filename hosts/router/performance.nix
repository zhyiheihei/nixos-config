{
  LT,
  lib,
  pkgs,
  ...
}:
let
  tc = "${pkgs.iproute2}/bin/tc";
  queueCount = LT.this.cpuThreads;
  flowEntriesPerQueue = 8192;
  # Both RTL8125 ports have queueCount RX queues, so the global RPS table
  # must cover 2 * queueCount queues.
  rpsFlowEntries = 2 * queueCount * flowEntriesPerQueue;

  rpsScript = pkgs.writeShellScript "router-rps" ''
    set -eu

    # Keep mq plus one fq_codel per hardware TX queue; replacing the root
    # with a single fq_codel collapses the two RTL8125 TX queues.
    if ! ${tc} qdisc show dev eth0 2>/dev/null | grep -q 'qdisc fq_codel.*parent'; then
      ${tc} qdisc replace dev eth0 root mq 2>/dev/null || true
      handle=$(${tc} qdisc show dev eth0 | awk '$1 == "qdisc" && $2 == "mq" { print $3; exit }')
      if [ -n "$handle" ]; then
        ${tc} qdisc replace dev eth0 parent "''${handle}1" fq_codel
        ${tc} qdisc replace dev eth0 parent "''${handle}2" fq_codel
      fi
    fi

    # One RX queue per core: the r8125 driver exposes eth0-0..3 / eth1-0..3
    # MSI-X vectors, but irqbalance packs several of them onto one CPU and
    # that caused NIC rx_missed/retransmits under multi-flow load.  Pin each
    # queue IRQ to its matching CPU instead and disable irqbalance below.
    for dev in eth0 eth1; do
      for q in $(seq 0 $(( ${toString queueCount} - 1 ))); do
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
          echo ${toString flowEntriesPerQueue} > "$q/rps_flow_cnt"
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
  # the RPS flow tables are sized for both NICs.  BBR is already enabled
  # globally by nixos/minimal-components/networking.nix.  NAPI and qdisc
  # values are backed by A/B medians in docs/human/research/10-router-rx-queue-4.md.
  boot.kernel.sysctl = {
    "net.core.netdev_budget" = 1200;
    "net.core.netdev_budget_usecs" = 30000;
    "net.core.flow_limit_table_len" = 16384;
    "net.core.netdev_max_backlog" = 5000;
    "net.core.optmem_max" = 131072;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.rps_sock_flow_entries" = rpsFlowEntries;
  };

  # The public default enables irqbalance on multi-core hosts, but its queue
  # placement hurt RTL8125 multi-queue performance on this board.  Keep the
  # network IRQs pinned by router-rps instead.
  services.irqbalance.enable = lib.mkForce false;

  systemd.services.router-rps = {
    description = "Reassert RTL8125 queue tuning, IRQ affinity and fq_codel";
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
      pkgs.iproute2
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = rpsScript;
      Restart = "on-failure";
      RestartSec = "5";
    };
  };

  # r8125 driver resets or link reinit can wipe qdisc/affinity/RPS settings
  # while systemd still reports the oneshot active; reassert every minute.
  systemd.timers.router-rps-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/1";
      Unit = "router-rps.service";
      Persistent = false;
    };
  };
}
