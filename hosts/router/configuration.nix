{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let

  vaults3Pkg = inputs.zhyi-packages.packages.${pkgs.system}.vaults3;
  vaults3Config = pkgs.writeText "vaults3.yaml" ''
    server:
      address: "0.0.0.0"
      port: 9000
    storage:
      data_dir: /mnt/storage/vaults3-data
      metadata_dir: /nix/persistent/var/lib/vaults3
  '';

  activationMarker = "/nix/persistent/var/lib/qbittorrent-router/ready";
  unifiedDownloadPath = "/mnt/storage/downloads";

  qbitPreStartPT = ''
    conf=/var/lib/qbittorrent-pt/qBittorrent/config/qBittorrent.conf
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    if ! grep -q '^\[BitTorrent\]$' "$conf"; then
      printf '[BitTorrent]\n' >> "$conf"
    fi
    if ! grep -q '^\[Preferences\]$' "$conf"; then
      printf '[Preferences]\n' >> "$conf"
    fi
    sed -i '/^Session\\DefaultSavePath=/d' "$conf"
    sed -i '/^Session\\Interface=/d' "$conf"
    sed -i '/^Session\\InterfaceName=/d' "$conf"
    sed -i '/^Session\\InterfaceAddress=/d' "$conf"
    sed -i '/^Session\\GlobalDLSpeedLimit=/d' "$conf"
    sed -i '/^Session\\GlobalUPSpeedLimit=/d' "$conf"
    sed -i '/^Session\\AsyncIOThreadsCount=/d' "$conf"
    sed -i '/^Session\\DiskCacheSize=/d' "$conf"
    sed -i '/^Session\\DiskCacheTTL=/d' "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DefaultSavePath=${unifiedDownloadPath}/" "$conf"
    # Leave Session\Interface unset ("Any interface"); reason documented at
    # the main instance's qbitPreStart (PPPoE redial re-bind, 2026-08-13).
    sed -i "/^\[BitTorrent\]$/a Session\\\\InterfaceAddress=0.0.0.0" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\GlobalDLSpeedLimit=0" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\GlobalUPSpeedLimit=2000" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\AsyncIOThreadsCount=4" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheSize=256" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheTTL=60" "$conf"
  '';

  qbitPreStart = ''
    conf=/var/lib/qbittorrent/qBittorrent/config/qBittorrent.conf
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    if ! grep -q '^\[BitTorrent\]$' "$conf"; then
      printf '[BitTorrent]\n' >> "$conf"
    fi
    if ! grep -q '^\[Preferences\]$' "$conf"; then
      printf '[Preferences]\n' >> "$conf"
    fi
    sed -i '/^Session\\DefaultSavePath=/d' "$conf"
    sed -i '/^Session\\Interface=/d' "$conf"
    sed -i '/^Session\\InterfaceName=/d' "$conf"
    sed -i '/^Session\\InterfaceAddress=/d' "$conf"
    sed -i '/^Session\\GlobalDLSpeedLimit=/d' "$conf"
    sed -i '/^Session\\GlobalUPSpeedLimit=/d' "$conf"
    sed -i '/^Session\\AsyncIOThreadsCount=/d' "$conf"
    sed -i '/^Session\\DiskCacheSize=/d' "$conf"
    sed -i '/^Session\\DiskCacheTTL=/d' "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DefaultSavePath=${unifiedDownloadPath}/" "$conf"
    # Leave Session\Interface unset ("Any interface"); reason documented at
    # the main instance's qbitPreStart (PPPoE redial re-bind, 2026-08-13).
    sed -i "/^\[BitTorrent\]$/a Session\\\\InterfaceAddress=0.0.0.0" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\GlobalDLSpeedLimit=10000" "$conf"
    # 2026-10-17 用户定：主实例（bt 刷流）上传锁定 2500KB/s——整夜上行
    # 峰值 87Mbps 后当日晨被运营商踢线进 CGNAT（pppd/miniupnpd 日志），
    # 全局总闸控制风控触发概率。
    sed -i "/^\[BitTorrent\]$/a Session\\\\GlobalUPSpeedLimit=2500" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\AsyncIOThreadsCount=4" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheSize=256" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheTTL=60" "$conf"
  '';

  metricsDir = "/var/lib/node-exporter-textfile";
  metricsFile = "${metricsDir}/router.prom";

  lanHostnames =
    lib.mapAttrs' (n: v: lib.nameValuePair v.interconnect.IPv4 (lib.removePrefix "_" n)) (
      lib.filterAttrs (n: v: v.interconnect.IPv4 != null && v.interconnect.name == "home-lan") LT.hosts
    )
    // {
      "192.168.0.40" = "qnap";
    };

  routerMetrics = pkgs.writeTextFile {
    name = "router-prometheus-metrics";
    destination = "/bin/router-prometheus-metrics";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.python3}
      import csv
      import json
      import os
      import subprocess

      hostname_map = json.loads('${builtins.toJSON lanHostnames}')
      import tempfile
      import time
      from pathlib import Path

      output = Path(${builtins.toJSON metricsFile})
      lease_file = Path("/var/lib/kea/dhcp4.leases")
      now = int(time.time())
      lines = [
          "# HELP router_dhcp_active_leases Number of active DHCPv4 leases.",
          "# TYPE router_dhcp_active_leases gauge",
          "# HELP router_dhcp_lease_info Active DHCPv4 lease information.",
          "# TYPE router_dhcp_lease_info gauge",
          "# HELP router_neighbor_info Current LAN neighbor information.",
          "# TYPE router_neighbor_info gauge",
          "# HELP router_neighbors Number of IPv4 neighbors grouped by state.",
          "# TYPE router_neighbors gauge",
          "# HELP router_conntrack_entries Current conntrack entries.",
          "# TYPE router_conntrack_entries gauge",
          "# HELP router_conntrack_limit Maximum conntrack entries.",
          "# TYPE router_conntrack_limit gauge",
          "# HELP router_wan_address_info Current PPPoE WAN address.",
          "# TYPE router_wan_address_info gauge",
      ]


      def label(value):
          return json.dumps(str(value), ensure_ascii=True)


      leases = {}
      if lease_file.exists():
          with lease_file.open(newline="") as handle:
              for row in csv.DictReader(handle):
                  if row.get("state") != "0" or int(row.get("expire", "0")) <= now:
                      continue
                  if row["address"] in leases:
                      # Kea can emit the same lease more than once; emitting
                      # duplicate label sets breaks the textfile collector.
                      continue
                  leases[row["address"]] = row
                  hostname = row.get("hostname") or ""
                  lines.append(
                      "router_dhcp_lease_info"
                      f"{{address={label(row['address'])},mac={label(row['hwaddr'])},"
                      f"hostname={label(hostname)}}} 1"
                  )
      lines.append(f"router_dhcp_active_leases {len(leases)}")

      neighbors = json.loads(
          subprocess.run(
              ["${lib.getExe' pkgs.iproute2 "ip"}", "-j", "neigh", "show", "dev", "br-lan"],
              check=True,
              capture_output=True,
              text=True,
          ).stdout
      )
      states = {}
      for neighbor in neighbors:
          mac = neighbor.get("lladdr")
          if not mac:
              continue
          state = (neighbor.get("state") or ["UNKNOWN"])[0]
          states[state] = states.get(state, 0) + 1
          address = neighbor.get("dst", "")
          hostname = leases.get(address, {}).get("hostname", "") or hostname_map.get(address, "")
          device = neighbor.get("dev") or "br-lan"
          family = "IPv6" if ":" in address else "IPv4"
          lines.append(
              "router_neighbor_info"
              f"{{address={label(address)},mac={label(mac)},hostname={label(hostname)},"
              f"device={label(device)},family={label(family)},state={label(state)}}} 1"
          )
      for state, count in sorted(states.items()):
          lines.append(f"router_neighbors{{state={label(state)}}} {count}")

      for metric, path in (
          ("router_conntrack_entries", "/proc/sys/net/netfilter/nf_conntrack_count"),
          ("router_conntrack_limit", "/proc/sys/net/netfilter/nf_conntrack_max"),
      ):
          try:
              lines.append(f"{metric} {Path(path).read_text().strip()}")
          except FileNotFoundError:
              pass

      addresses = json.loads(
          subprocess.run(
              ["${lib.getExe' pkgs.iproute2 "ip"}", "-j", "-4", "address", "show", "dev", "ppp0"],
              check=False,
              capture_output=True,
              text=True,
          ).stdout
          or "[]"
      )
      for interface in addresses:
          for address in interface.get("addr_info", []):
              if address.get("family") == "inet":
                  lines.append(
                      f"router_wan_address_info{{address={label(address['local'])}}} 1"
                  )

      output.parent.mkdir(parents=True, exist_ok=True)
      fd, temporary = tempfile.mkstemp(prefix=".router.", dir=output.parent)
      try:
          with os.fdopen(fd, "w") as handle:
              handle.write("\n".join(lines) + "\n")
          os.chmod(temporary, 0o644)
          os.replace(temporary, output)
      finally:
          if os.path.exists(temporary):
              os.unlink(temporary)
    '';
  };

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
        # 行尾必须吞掉单位后缀（iputils 输出 "... /0.104 ms"），否则 prom 文本格式把 ms 当 timestamp 解析失败，整个 textfile 被丢弃
        avg=$(printf '%s\n' "$out_ping" | sed -n 's/.*= \([0-9][0-9.]*\)\/[0-9.]*\/[0-9.]*\/[0-9.]*.*/\1/p' | head -1)
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
  imports = [
    ../../nixos/minimal.nix

    ./ddns.nix
    ./dhcp.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/common-apps/nginx/nginx.nix
    ../../nixos/common-apps/nginx/vhost-options/default.nix

    ../../nixos/common-apps/nginx/vhosts-default.nix
    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/optional-apps/miniupnpd.nix
    ../../nixos/optional-apps/nmea-static-gps-server.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/qbittorrent.nix
    ../../nixos/optional-apps/qbittorrent-pt.nix
  ];

  boot.supportedFilesystems = lib.mkForce [
    "btrfs"
    "ext4"
    "vfat"
    "nfs"
  ];
  environment.systemPackages = [ pkgs.nfs-utils ];

  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "noatime"
      "noauto"
      "hard"
      "vers=4.1"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };

  systemd.units."mnt-storage.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
  };

  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@br-lan.service" ];

  services.miniupnpd = {
    externalInterface = "ppp0";
    internalIPs = [ "br-lan" ];
  };

  services.zerotierone.localConf.settings.interfacePrefixBlacklist = lib.mkForce (
    pkgs.callPackage ../../nixos/minimal-components/zerotier/whitelist_to_blacklist.nix { } (
      (builtins.filter (v: v != "ns") (
        LT.constants.interfacePrefixes.WAN ++ LT.constants.interfacePrefixes.LAN
      ))
      ++ [ "ppp" ]
    )
  );

  users.users.vaults3 = {
    isSystemUser = true;
    group = "vaults3";
  };
  users.groups.vaults3 = { };

  sops.templates.vaults3-credentials = {
    content = ''
      VAULTS3_ACCESS_KEY=zhyi
      VAULTS3_SECRET_KEY=${config.sops.placeholder.default-pw}
    '';
    mode = "0400";
    owner = "vaults3";
    group = "vaults3";
  };

  systemd.tmpfiles.settings.vaults3 = {
    "/nix/persistent/var/lib/vaults3".d = {
      mode = "0700";
      user = "vaults3";
      group = "vaults3";
    };
  };

  systemd.services.vaults3 = {
    description = "VaultS3 S3-compatible object storage";
    wantedBy = [ "multi-user.target" ];
    after = [
      "mnt-storage.mount"
      "network.target"
      "sops-install-secrets.service"
    ];
    requires = [ "mnt-storage.mount" ];
    unitConfig = {
      RequiresMountsFor = [ "/mnt/storage/vaults3-data" ];
      ConditionPathExists = "/nix/persistent/var/lib/vaults3/ready";
    };
    environment = {
      VAULTS3_DATA_DIR = "/mnt/storage/vaults3-data";
      VAULTS3_METADATA_DIR = "/nix/persistent/var/lib/vaults3";
    };
    serviceConfig = {
      Type = "simple";
      User = "vaults3";
      Group = "vaults3";
      PrivateUsers = false;
      BindPaths = [
        "/mnt/storage/vaults3-data"
        "/nix/persistent/var/lib/vaults3"
      ];
      BindReadOnlyPaths = [ config.sops.templates.vaults3-credentials.path ];
      EnvironmentFile = config.sops.templates.vaults3-credentials.path;
      ExecStart = "${vaults3Pkg}/bin/vaults3 -config ${vaults3Config}";
      Restart = "on-failure";
      RestartSec = "5";
      ReadWritePaths = [
        "/mnt/storage/vaults3-data"
        "/nix/persistent/var/lib/vaults3"
      ];
    };
  };

  lantian.harden.vaults3 = {
    enable = true;
    enableConfinement = false;
  };

  services.qbittorrent = {
    package = lib.mkForce pkgs.qbittorrent-nox;
    torrentingPort = lib.mkForce 31220;
  };

  lantian.nginxVhosts = {
    "bt.${config.networking.hostName}.zhyi.xin".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    "bt.localhost".locations."/".proxyPass = lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
  };

  systemd.tmpfiles.settings.qbittorrent-router = {
    "/mnt/storage".d = {
      mode = "755";
      user = "root";
      group = "root";
    };
    "${unifiedDownloadPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
    "/nix/persistent/var/lib/qbittorrent-router".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };

  systemd.services.qbittorrent = {
    unitConfig.ConditionPathExists = activationMarker;
    after = [
      "var-lib.mount"
      "mnt-storage.mount"
    ];
    requires = [
      "var-lib.mount"
      "mnt-storage.mount"
    ];
    serviceConfig = {
      StateDirectory = "qbittorrent";
      BindPaths = [ unifiedDownloadPath ];
    };
    preStart = lib.mkAfter qbitPreStart;
  };
  lantian.harden.qbittorrent.enable = true;

  systemd.services.qbittorrent-pt = {
    unitConfig.ConditionPathExists = activationMarker;
    after = [
      "var-lib.mount"
      "mnt-storage.mount"
    ];
    requires = [
      "var-lib.mount"
      "mnt-storage.mount"
    ];
    serviceConfig = {
      StateDirectory = "qbittorrent-pt";
      BindPaths = [ unifiedDownloadPath ];
    };
    preStart = lib.mkAfter qbitPreStartPT;
  };

  lantian.nginxVhosts = {
    "pt.${config.networking.hostName}.zhyi.xin".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrentPT.WebUI}";
    "pt.localhost".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrentPT.WebUI}";
  };

  systemd.tmpfiles.settings.qbittorrent-pt-router = {
    "${unifiedDownloadPath}".d = {
      mode = "755";
      user = "zhyi";
      group = "users";
    };
  };

  systemd.services.miniupnpd.preStart = ''
    ${lib.getExe' pkgs.iproute2 "ip"} -4 addr show ppp0 | ${lib.getExe' pkgs.gawk "awk"} "/inet /{print \$2; exit}" > /run/miniupnpd/wan-addr || true
  '';
  systemd.services.miniupnpd.serviceConfig.RuntimeDirectory = "miniupnpd";

  systemd.services.miniupnpd-watchdog = {
    after = [
      "miniupnpd.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "miniupnpd-watchdog" ''
        cur=$(${lib.getExe' pkgs.iproute2 "ip"} -4 addr show ppp0 2>/dev/null | ${lib.getExe' pkgs.gawk "awk"} "/inet /{print \$2; exit}")
        [ -n "$cur" ] || exit 0
        [ -f /run/miniupnpd/wan-addr ] || exit 0
        started=$(cat /run/miniupnpd/wan-addr)
        if [ "$started" != "$cur" ]; then
          ${lib.getExe' pkgs.systemd "systemctl"} try-restart miniupnpd.service
        fi
      '';
    };
  };
  systemd.timers.miniupnpd-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "1min";
      Unit = "miniupnpd-watchdog.service";
    };
  };

  services.prometheus.exporters.node = {
    enabledCollectors = lib.mkAfter [ "textfile" ];
    extraFlags = [
      "--collector.textfile.directory=${metricsDir}"
    ];
  };

  systemd.tmpfiles.settings.router-prometheus.${metricsDir}.d = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  systemd.services.router-prometheus-metrics = {
    description = "Export router DHCP and neighbor metrics";
    serviceConfig = {
      AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
      CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
      Type = "oneshot";
      ExecStart = "${routerMetrics}/bin/router-prometheus-metrics";
      ProcSubset = "all";
      BindReadOnlyPaths = [ "/var/lib/kea" ];
      ReadWritePaths = [ metricsDir ];
    };
  };
  lantian.harden.router-prometheus-metrics.enable = "network";

  systemd.timers.router-prometheus-metrics = {
    description = "Refresh router DHCP and neighbor metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      Unit = "router-prometheus-metrics.service";
    };
  };

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
