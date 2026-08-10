{
  pkgs,
  ...
}:
{
  # Follow the OpenWrt NanoPi R5C high-throughput recipe that is backed by
  # community measurements: raise device/socket buffers and spread RX load
  # across all four RK3568 cores.  BBR is already enabled globally by
  # nixos/minimal-components/networking.nix.
  boot.kernel.sysctl = {
    "net.core.netdev_max_backlog" = 5000;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
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
      ExecStart = [
        "${pkgs.runtimeShell} -c 'echo f > /sys/class/net/eth0/queues/rx-0/rps_cpus || true'"
        "${pkgs.runtimeShell} -c 'echo 4096 > /sys/class/net/eth0/queues/rx-0/rps_flow_cnt || true'"
        "${pkgs.runtimeShell} -c 'echo f > /sys/class/net/eth1/queues/rx-0/rps_cpus || true'"
        "${pkgs.runtimeShell} -c 'echo 4096 > /sys/class/net/eth1/queues/rx-0/rps_flow_cnt || true'"
      ];
    };
  };
}
