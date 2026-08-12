{
  ...
}:
let
  user = "zhyi";
  group = "users";
  unifiedDownloadPath = "/mnt/storage/downloads";
in
{
  systemd.tmpfiles.settings.qbittorrent-router = {
    "/mnt/storage".d = {
      mode = "755";
      user = "root";
      group = "root";
    };
    "${unifiedDownloadPath}".d = {
      mode = "755";
      inherit user group;
    };
    "/nix/persistent/var/lib/qbittorrent-router".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };

  systemd.services.qbittorrent = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    serviceConfig.BindPaths = [ unifiedDownloadPath ];
  };
}
