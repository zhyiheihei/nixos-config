{
  lib,
  pkgs,
  ...
}:
let
  tc = "${pkgs.iproute2}/bin/tc";
  # Both NICs are single-queue (dwmac-rockchip eth0, r8169 eth1), so the
  # global RPS table must cover 2 queues, one per port.
  flowEntriesPerQueue = 8192;
  rpsFlowEntries = 2 * flowEntriesPerQueue;

  rpsScript = pkgs.writeShellScript "h28k-rps" ''
    set -eu

    # Single-queue NICs: replace the default mq/pfifo_fast root with fq_codel
    # directly (the R5C A/B in docs/research/10 showed fq_codel halves
    # retransmits at equal or better throughput).
    for dev in eth0 eth1; do
      ${tc} qdisc replace dev "$dev" root fq_codel 2>/dev/null || true
    done

    # Pin each port's IRQ to its own CPU: eth0 is the MAC IRQ (the stmmac
    # "sfty" IRQ is unused), eth1 is the PCIe MSI-X vector. irqbalance is
    # disabled below so these stick.
    for entry in "eth0 0" "eth1 1"; do
      set -- $entry
      dev=$1
      cpu=$2
      irq=$(awk -v dev="$dev" '$NF == dev { sub(":", "", $1); print $1; exit }' /proc/interrupts)
      if [ -n "$irq" ]; then
        echo "$cpu" > "/proc/irq/$irq/smp_affinity_list"
      fi
    done

    # Spread the single RX queue across all four cores with RPS and pin XPS
    # the same way. r8169 does not expose xps_cpus; guard with if so the
    # missing file does not abort the script under set -e.
    for dev in eth0 eth1; do
      for q in /sys/class/net/$dev/queues/rx-*; do
        if [ -e "$q/rps_cpus" ]; then
          echo f > "$q/rps_cpus"
        fi
        if [ -e "$q/rps_flow_cnt" ]; then
          echo ${toString flowEntriesPerQueue} > "$q/rps_flow_cnt"
        fi
      done
      for q in /sys/class/net/$dev/queues/tx-*; do
        if [ -e "$q/xps_cpus" ]; then
          echo f > "$q/xps_cpus"
        fi
      done
    done

    # The H28K board enables EEE with an aggressive Tx LPI timer on both
    # PHYs (1 s on the RTL8211F); disable it like the R5C recipe does.
    for dev in eth0 eth1; do
      ${pkgs.ethtool}/bin/ethtool --set-eee "$dev" eee off 2>/dev/null || true
    done
  '';
in
{
  # R5C router high-throughput recipe (docs/research/10-router-rx-queue-4.md):
  # raise device/socket buffers and spread RX processing across all cores.
  # BBR is already enabled globally by nixos/minimal-components/networking.nix.
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
  # placement hurt multi-queue performance on the R5C router; keep the H28K
  # network IRQs pinned by h28k-rps instead.
  services.irqbalance.enable = lib.mkForce false;

  systemd.services.h28k-rps = {
    description = "Reassert H28K queue tuning, IRQ affinity, fq_codel and EEE";
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

  # Driver resets or link reinit can wipe qdisc/affinity/RPS settings while
  # systemd still reports the oneshot active; reassert every minute.
  systemd.timers.h28k-rps-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/1";
      Unit = "h28k-rps.service";
      Persistent = false;
    };
  };
}
