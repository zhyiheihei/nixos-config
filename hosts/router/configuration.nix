# 与上游 lt-home-router 同构：主题文件止步于 ddns/dhcp/firewall/networking，
# 各服务的定义与取值调整全部落在主配置。
{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  utils,
  ...
}:
let
  ########################################
  # v2ray（全仓出站代理的统一入口）
  ########################################

  v2rayConf = {
    inbounds = [
      {
        listen = LT.this.interconnect.IPv4;
        port = LT.port.V2Ray.SocksClient;
        protocol = "socks";
        settings.udp = true;
        sniffing = {
          destOverride = [
            "http"
            "tls"
            "quic"
          ];
          enabled = true;
        };
        tag = "inbound";
      }
    ];
    log = {
      access = "none";
      loglevel = "warning";
    };
    outbounds = [
      {
        protocol = "vless";
        settings.vnext = [
          {
            address = LT.publicIPv4For "tencent";
            port = 443;
            users = [
              {
                id = {
                  _secret = config.sops.secrets.v2ray-key.path;
                };
                encryption = "none";
              }
            ];
          }
        ];
        streamSettings =
          let
            network = "xhttp";
            security = "tls";
            tlsSettings = {
              serverName = "tencent.zhyi.xin";
              fingerprint = "firefox";
            };
            xhttpSettings = {
              host = "tencent.zhyi.xin";
              path = "/ray";
              xmux = {
                maxConcurrency = 128;
                hMaxRequestTimes = 86400;
                hMaxReusableSecs = 86400;
              };
            };
          in
          {
            inherit network security tlsSettings;
            xhttpSettings = xhttpSettings // {
              mode = "stream-up";
              downloadSettings = {
                address = LT.publicIPv4For "tencent";
                port = 443;
                inherit
                  network
                  security
                  tlsSettings
                  xhttpSettings
                  ;
              };
            };
          };
        tag = "proxy";
      }
      {
        protocol = "freedom";
        settings.domainStrategy = "UseIPv4";
        tag = "direct";
      }
      {
        protocol = "blackhole";
        settings.response.type = "none";
        tag = "block";
      }
    ];
    policy.levels."0" = {
      connIdle = 86400;
      downlinkOnly = 0;
      uplinkOnly = 0;
    };
    routing = {
      balancers = [ ];
      domainStrategy = "IPOnDemand";
      # Unmatched traffic uses the first outbound (`proxy`) by default. Newer
      # Xray rejects an empty `field` rule as "no effective fields".
      rules = [
        {
          outboundTag = "block";
          protocol = [ "bittorrent" ];
          type = "field";
        }
        {
          domain = [
            "geosite:category-ads"
            "geosite:category-ads-all"
          ];
          outboundTag = "block";
          type = "field";
        }
        {
          domain = [
            "geosite:private"
            "geosite:cn"
            "category-games@cn"
          ];
          outboundTag = "direct";
          type = "field";
        }
        {
          ip = [
            "geoip:private"
            "geoip:cn"
          ];
          outboundTag = "direct";
          type = "field";
        }
      ];
    };
  };

  ########################################
  # VaultS3 对象存储
  ########################################

  vaults3Pkg = inputs.zhyi-packages.packages.${pkgs.system}.vaults3;
  vaults3Config = pkgs.writeText "vaults3.yaml" ''
    server:
      address: "0.0.0.0"
      port: 9000
    storage:
      data_dir: /mnt/storage/vaults3-data
      metadata_dir: /nix/persistent/var/lib/vaults3
  '';

  ########################################
  # qBittorrent（下载链主力，自 opi5p 迁入）
  ########################################

  activationMarker = "/nix/persistent/var/lib/qbittorrent-router/ready";
  authSubnetWhitelist = "192.168.0.62,192.168.0.64";
  unifiedDownloadPath = "/mnt/storage/downloads";
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
    sed -i '/^Session\\AsyncIOThreadsCount=/d' "$conf"
    sed -i '/^Session\\DiskCacheSize=/d' "$conf"
    sed -i '/^Session\\DiskCacheTTL=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelistEnabled=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelist=/d' "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DefaultSavePath=${unifiedDownloadPath}/" "$conf"
    # Leave Session\Interface unset ("Any interface") instead of pinning ppp0.
    # Verified 2026-08-13 on qbittorrent 5.2.3 / libtorrent 2.0.13: with
    # InterfaceAddress=0.0.0.0 qBittorrent listens IPv4-only (the two global
    # IPv6 addresses on ppp0 are not listened, so PTTime keeps single-IP
    # announces) and re-binds automatically when ppp0's address changes after
    # a PPPoE redial — the previous ppp0-pinned listener kept the stale IP
    # until a manual restart, stalling all downloads (2026-08-13 incident).
    sed -i "/^\[BitTorrent\]$/a Session\\\\InterfaceAddress=0.0.0.0" "$conf"
    # Full broadband throughput requires removing the 10MB/s global download
    # cap that was carried into the migrated runtime config.
    sed -i "/^\[BitTorrent\]$/a Session\\\\GlobalDLSpeedLimit=0" "$conf"
    # qBittorrent defaults to 10 async IO threads and an auto-sized disk
    # cache; on the 4-core R5C router cap both to keep torrent IO from
    # starving NAT/softirq work (measured 2026-08-12: load 9-13 -> ~4.6,
    # WAN rx_missed 0).  Keys verified in qbittorrent release-5.2.3
    # sessionimpl.cpp.
    sed -i "/^\[BitTorrent\]$/a Session\\\\AsyncIOThreadsCount=4" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheSize=256" "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DiskCacheTTL=60" "$conf"
    sed -i '/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelistEnabled=true' "$conf"
    sed -i "/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelist=${authSubnetWhitelist}" "$conf"
  '';

  ########################################
  # Prometheus textfile 指标（邻居/DHCP/连通性）
  ########################################

  metricsDir = "/var/lib/node-exporter-textfile";
  metricsFile = "${metricsDir}/router.prom";

  # Map home-LAN IPs to hostnames for devices without a DHCP lease (static
  # servers); DHCP leases remain the primary source for dynamic clients.
  lanHostnames = lib.mapAttrs' (
    n: v:
    lib.nameValuePair v.interconnect.IPv4 (lib.removePrefix "_" n)
  ) (
    lib.filterAttrs (n: v: v.interconnect.IPv4 != null && v.interconnect.name == "home-lan") LT.hosts
  ) // {
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
    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/optional-apps/miniupnpd.nix
    ../../nixos/optional-apps/nmea-static-gps-server.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/qbittorrent.nix
  ];

  # The R5C hardware module force-replaces boot.supportedFilesystems; mirror
  # its list and add NFS at host level. The kernel config already has
  # CONFIG_NFS_FS=y and nfs-utils supplies mount.nfs.
  boot.supportedFilesystems = lib.mkForce [
    "btrfs"
    "ext4"
    "vfat"
    "nfs"
  ];
  environment.systemPackages = [ pkgs.nfs-utils ];

  # Same QNAP export the other media hosts mount.  Router must stay up as the
  # LAN gateway even when the NAS is down, so keep the mount non-fatal.
  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "noatime"
      "hard"
      "vers=4.1"
      "nconnect=16"
    ];
  };

  # Global wait-online is disabled by minimal networking; wait for the static
  # LAN bridge before attempting the NFS mount, mirroring opi5p's lan0 setup.
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@br-lan.service" ];

  services.miniupnpd = {
    externalInterface = "ppp0";
    internalIPs = [ "br-lan" ];
  };

  # The fleet-wide ZeroTier interface whitelist has no "ppp" prefix (the
  # author's routers dial via VLAN subinterfaces like eth1.201), so ppp0 lands
  # in the generated blacklist and this router's daemon cannot bind the PPPoE
  # uplink: no packets ever come back from the PLANET roots (paths=[] on every
  # peer) and the whole home-LAN overlay stalls behind the missing controller
  # reachability. Re-derive the blacklist from the stock whitelist (netns
  # prefixes excluded, same as the module) plus "ppp".
  services.zerotierone.localConf.settings.interfacePrefixBlacklist = lib.mkForce
    (pkgs.callPackage ../../nixos/minimal-components/zerotier/whitelist_to_blacklist.nix { }
      ((builtins.filter (v: v != "ns") (LT.constants.interfacePrefixes.WAN
        ++ LT.constants.interfacePrefixes.LAN))
        ++ [ "ppp" ])
    );

  # h28k declares its own site interconnect (h28k-lan), so the module-generated
  # try list has no hint for it, but while staging at home the board is on the
  # same subnet as this router (192.168.0.139). Without a hint neither node
  # ever learns the other's identity and every frame from it is dropped
  # (peer tables stay mutually empty). Mirror the module's try-list derivation
  # but treat h28k as reachable by its home-lan IP. Remove together with
  # hosts/h28k/configuration.nix's matching override after the relocation.
  services.zerotierone.localConf.virtual = lib.mkForce
    (lib.mapAttrs'
      (k: host:
        let
          interconnectIPv4 =
            if host.interconnect.name != null && host.interconnect.IPv4 != null
                && (host.interconnect.name == "home-lan" || host.hostname == "h28k.zhyi.xin")
            then host.interconnect.IPv4
            else null;
        in
          lib.nameValuePair host.zerotier {
            try =
              (lib.optionals (interconnectIPv4 != null) [ "${interconnectIPv4}/9993" ])
              ++ (lib.optionals (host.public.IPv4 != null) [ "${host.public.IPv4}/9993" ])
              ++ (lib.optionals (host.public.IPv6 != null) [ "${host.public.IPv6}/9993" ])
              ++ (lib.optionals (host.public.IPv6Alt != null) [ "${host.public.IPv6Alt}/9993" ]);
          })
      (lib.filterAttrs (n: v: v.zerotier != null) LT.otherHosts));

  ########################################
  # v2ray
  ########################################

  sops.secrets = lib.genAttrs [ "v2ray-key" ] (_: {
    sopsFile = inputs.secrets + "/common/v2ray.yaml";
    owner = "v2ray";
    group = "v2ray";
  });

  systemd.services.v2ray = {
    description = "v2ray Daemon";
    after = [ "network.target" "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
    environment =
      let
        assets = pkgs.symlinkJoin {
          name = "v2ray-assets";
          paths = with pkgs; [
            v2ray-geoip
            v2ray-domain-list-community
          ];
        };
      in
      {
        V2RAY_LOCATION_ASSET = "${assets}/share/v2ray";
        XRAY_LOCATION_ASSET = "${assets}/share/v2ray";
      };
    script = ''
      rm -f /run/v2ray/v2ray.sock

      ${utils.genJqSecretsReplacementSnippet v2rayConf "/run/v2ray/config.json"}

      exec ${lib.getExe pkgs.xray} -config /run/v2ray/config.json
    '';
    serviceConfig = LT.serviceHarden // {
      User = "v2ray";
      Group = "v2ray";
      RuntimeDirectory = "v2ray";
      Restart = "always";
      RestartSec = 5;
    };
  };

  users.users.v2ray = {
    group = "v2ray";
    isSystemUser = true;
  };
  users.groups.v2ray = { };

  ########################################
  # VaultS3
  ########################################

  users.users.vaults3 = {
    isSystemUser = true;
    group = "vaults3";
  };
  users.groups.vaults3 = { };

  # VaultS3 uses the fleet-wide account/password convention: access key is the
  # unified account and the secret key comes from the shared default-pw secret.
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
    serviceConfig = LT.serviceHarden // {
      Type = "simple";
      User = "vaults3";
      Group = "vaults3";
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

  ########################################
  # qBittorrent
  ########################################

  # Public module stays upstream-aligned; router only adds host-specific
  # extension keys: official client, fixed port, one WAN interface, unified
  # save path, and LAN auth bypass.
  services.qbittorrent = {
    package = lib.mkForce pkgs.qbittorrent-nox;
    torrentingPort = lib.mkForce 31220;
  };

  # This router's qBittorrent build does not treat IPv4 127.0.0.1 as loopback
  # for the WebUI auth bypass, while [::1] works. Keep the author-style vhost
  # structure and only change the host-level backend address.
  lantian.nginxVhosts = {
    "bt.${config.networking.hostName}.zhyi.xin".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
    "bt.localhost".locations."/".proxyPass =
      lib.mkForce "http://[::1]:${LT.portStr.qBitTorrent.WebUI}";
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
    serviceConfig.BindPaths = [ unifiedDownloadPath ];
    preStart = lib.mkAfter qbitPreStart;
  };

  ########################################
  # Prometheus textfile metrics
  ########################################

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
    serviceConfig = LT.networkToolHarden // {
      AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
      CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
      Type = "oneshot";
      ExecStart = "${routerMetrics}/bin/router-prometheus-metrics";
      ProcSubset = "all";
      ReadWritePaths = [ metricsDir ];
    };
  };

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
