{
  pkgs,
  ...
}:
let
  rpsScript = pkgs.writeShellScript "router-rps" ''
    set -eu
    for dev in eth0 eth1; do
      for q in /sys/class/net/$dev/queues/rx-*; do
        if [ -e "$q/rps_cpus" ]; then
          echo f > "$q/rps_cpus"
          echo 4096 > "$q/rps_flow_cnt"
        fi
      done
    done
  '';
in
{
  # Follow the OpenWrt NanoPi R5C high-throughput recipe that is backed by
  # community measurements: raise device/socket buffers and spread every RX
  # queue across all four RK3568 cores.  BBR is already enabled globally by
  # nixos/minimal-components/networking.nix.
  boot.kernel.sysctl = {
    "net.core.netdev_max_backlog" = 5000;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.rps_sock_flow_entries" = 4096;
  };

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
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = rpsScript;
      Restart = "on-failure";
      RestartSec = "5";
    };
  };
}
