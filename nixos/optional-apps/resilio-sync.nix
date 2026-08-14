{
  lib,
  LT,
  config,
  pkgs,
  ...
}:
{
  options.lantian.resilioSync = {
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/resilio-sync";
      description = "Directory holding Resilio Sync identity and database files";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/resilio-sync/data";
      description = "Root directory of the synced folders (mounted at /sync)";
    };

    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/resilio-sync/downloads";
      description = "Default downloads directory (mounted at /downloads)";
    };
  };

  config = {
    users.users.resilio-sync = {
      description = "Resilio Sync user";
      isSystemUser = true;
      # Fixed id so migrated data can be chowned before deployment; 1002 is
      # free on the fleet (zhyi=1000, nix-builder=1001, nscd=998, etc.).
      uid = 1002;
      group = "resilio-sync";
    };
    users.groups.resilio-sync.gid = 1002;

    # Folder paths inside the Resilio Sync database are hardcoded to /sync
    # and /downloads; bind those paths to the configured directories so a
    # migrated identity keeps working unchanged.
    fileSystems."/sync" = {
      device = config.lantian.resilioSync.dataDir;
      fsType = "auto";
      options = [ "bind" ];
    };
    fileSystems."/downloads" = {
      device = config.lantian.resilioSync.downloadsDir;
      fsType = "auto";
      options = [ "bind" ];
    };

    systemd.tmpfiles.settings.resilio-sync = {
      "${config.lantian.resilioSync.configDir}"."d" = {
        mode = "0700";
        user = "resilio-sync";
        group = "resilio-sync";
      };
      "${config.lantian.resilioSync.dataDir}"."d" = {
        mode = "0750";
        user = "resilio-sync";
        group = "resilio-sync";
      };
      "${config.lantian.resilioSync.downloadsDir}"."d" = {
        mode = "0750";
        user = "resilio-sync";
        group = "resilio-sync";
      };
    };

    systemd.services.resilio = {
      description = "Resilio Sync";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = [ "/sync" "/downloads" ];
      serviceConfig = LT.networkToolHarden // {
        Type = "simple";
        User = "resilio-sync";
        Group = "resilio-sync";
        ExecStart = "${lib.getExe pkgs.resilio-sync} --config ${config.lantian.resilioSync.configDir} --nodaemon";
        StateDirectory = "resilio-sync";
        ReadWritePaths = [ "/sync" "/downloads" ];
        Environment = "HOME=${config.lantian.resilioSync.configDir}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
