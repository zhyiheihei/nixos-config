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
            ];
          }
        ];
      }
    ))
  ];
}
