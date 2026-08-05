{
  pkgs,
  lib,
  ...
}:
let
  metricsDir = "/var/lib/node-exporter-textfile";
  metricsFile = "${metricsDir}/accelerator.prom";

  acceleratorMetrics = pkgs.writeTextFile {
    name = "rockchip-accelerator-metrics";
    destination = "/bin/rockchip-accelerator-metrics";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.python3}
      import os
      import re
      import tempfile
      from pathlib import Path

      output = Path(${builtins.toJSON metricsFile})
      lines = [
          "# HELP rockchip_gpu_load_percent Rockchip GPU load percentage from devfreq.",
          "# TYPE rockchip_gpu_load_percent gauge",
          "# HELP rockchip_gpu_freq_hz Rockchip GPU current frequency in Hz.",
          "# TYPE rockchip_gpu_freq_hz gauge",
          "# HELP rockchip_npu_load_percent Rockchip NPU load percentage (max of per-core debugfs loads).",
          "# TYPE rockchip_npu_load_percent gauge",
          "# HELP rockchip_npu_freq_hz Rockchip NPU current frequency in Hz.",
          "# TYPE rockchip_npu_freq_hz gauge",
          "# HELP rockchip_npu_core_load_percent Rockchip NPU per-core load percentage.",
          "# TYPE rockchip_npu_core_load_percent gauge",
      ]

      def devfreq_metrics(device, kind, load=True):
          path = Path(f"/sys/class/devfreq/{device}/load")
          if not path.is_file():
              return
          text = path.read_text().strip()
          percent, separator, freq = text.partition("@")
          if not separator:
              return
          if load:
              lines.append(f"rockchip_{kind}_load_percent {percent}")
          lines.append(f"rockchip_{kind}_freq_hz {freq.removesuffix('Hz')}")

      devfreq_metrics("fb000000.gpu", "gpu")
      devfreq_metrics("fdab0000.npu", "npu", load=False)

      rknpu = Path("/sys/kernel/debug/rknpu/load")
      npu_core_loads = []
      if rknpu.is_file():
          text = rknpu.read_text()
          for core, percent in re.findall(r"Core(\d+):\s+(\d+)%", text):
              npu_core_loads.append(int(percent))
              lines.append(f'rockchip_npu_core_load_percent{{core="{core}"}} {percent}')
      if npu_core_loads:
          lines.append(f"rockchip_npu_load_percent {max(npu_core_loads)}")

      output.parent.mkdir(parents=True, exist_ok=True)
      fd, temporary = tempfile.mkstemp(prefix=".accelerator.", dir=output.parent)
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

  systemd.tmpfiles.settings.rockchip-accelerator-metrics.${metricsDir}.d = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  systemd.services.rockchip-accelerator-metrics = {
    description = "Export Rockchip GPU and NPU utilization metrics";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${acceleratorMetrics}/bin/rockchip-accelerator-metrics";
      ReadWritePaths = [ metricsDir ];
      Restart = "on-failure";
    };
  };

  systemd.timers.rockchip-accelerator-metrics = {
    description = "Refresh Rockchip GPU and NPU metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "15s";
      Unit = "rockchip-accelerator-metrics.service";
    };
  };
}
