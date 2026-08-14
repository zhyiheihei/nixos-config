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
        # rslsync takes the config FILE path (a directory fails with "Error
        # while reading config file"); the identity/database files live next
        # to sync.conf per storage_path inside it.
        ExecStart = "${lib.getExe pkgs.resilio-sync} --config ${config.lantian.resilioSync.configDir}/sync.conf --nodaemon";
        # Fresh deployments have no sync.conf yet; rslsync would exit without
        # writing one, so seed a minimal default matching the module layout.
        ExecStartPre =
          let
            defaultConf = pkgs.writeText "resilio-default-sync.conf" (
              builtins.toJSON {
                storage_path = config.lantian.resilioSync.configDir;
                directory_root = "/sync/";
                files_default_path = "/downloads";
                webui.listen = "0.0.0.0:8888";
              }
            );
          in
          "${pkgs.coreutils}/bin/test -f ${config.lantian.resilioSync.configDir}/sync.conf || ${pkgs.coreutils}/bin/install -m 0600 -o resilio-sync -g resilio-sync ${defaultConf} ${config.lantian.resilioSync.configDir}/sync.conf";
        StateDirectory = "resilio-sync";
        ReadWritePaths = [ "/sync" "/downloads" ];
        Environment = "HOME=${config.lantian.resilioSync.configDir}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
