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
                expr = ''node_filesystem_size_bytes{instance="ml-home-vm",mountpoint="/mnt/storage"}'';
                labels.name = "ml-home-vm";
              }
              {
                record = "storagebox_disk_usage";
                expr = ''node_filesystem_size_bytes{instance="ml-home-vm",mountpoint="/mnt/storage"} - node_filesystem_avail_bytes{instance="ml-home-vm",mountpoint="/mnt/storage"}'';
                labels.name = "ml-home-vm";
              }
              {
                alert = "storagebox_metrics_absent";
                expr = ''absent(storagebox_disk_quota{name="ml-home-vm"})'';
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
