{
  pkgs,
  lib,
  LT,
  ...
}:
let
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
in
{
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
}
