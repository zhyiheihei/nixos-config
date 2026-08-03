{ pkgs, ... }:
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "prometheus-storagebox.rules" (
      builtins.toJSON {
        groups = [
          {
            name = "storagebox";
            rules = [
              {
                record = "storagebox_disk_quota";
                expr = ''node_filesystem_size_bytes{instance="opi5p",mountpoint="/mnt/storage"}'';
                labels.name = "opi5p";
              }
              {
                record = "storagebox_disk_usage";
                expr = ''node_filesystem_size_bytes{instance="opi5p",mountpoint="/mnt/storage"} - node_filesystem_avail_bytes{instance="opi5p",mountpoint="/mnt/storage"}'';
                labels.name = "opi5p";
              }
              {
                alert = "storagebox_metrics_absent";
                expr = ''absent(storagebox_disk_quota{name="opi5p"})'';
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  summary = "Storage metrics for {{$labels.name}} are unavailable.";
                  description = "Storage metrics for {{$labels.name}} have been absent for 10 minutes.";
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
