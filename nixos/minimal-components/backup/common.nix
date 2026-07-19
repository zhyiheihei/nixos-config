{
  lib,
  pkgs,
  config,
  ...
}:
rec {
  resticIgnored = ''
    media/
    sftp-server/
    tmp/
    var/cache/
    var/lib/asterisk/
    var/lib/btrfs/
    var/lib/cni/
    var/lib/containers/
    var/lib/crowdsec/
    var/lib/docker/
    var/lib/docker-dind/
    var/lib/filebeat/
    var/lib/GeoIP/
    var/lib/grafana/
    var/lib/jellyfin/transcodes/
    var/lib/libvirt/
    var/lib/machines/
    var/lib/os-prober/
    var/lib/private/
    var/lib/prometheus/
    var/lib/resilio-sync/*.db
    var/lib/resilio-sync/*.db-wal
    var/lib/samba/private/
    var/lib/systemd/
    var/lib/udisks2/
    var/lib/vm/
    var/lib/vz/
    var/log/
  '';

  resticRepos = {
    home = ''
      [repository]
      repository = "opendal:sftp"
      password-file = "${config.sops.secrets.restic-pw.path}"
      cache-dir = "/var/cache/restic/home"

      [repository.options]
      user = "sftp"
      endpoint = "ssh://sftp.ml-home-vm.zhyi.cc:2222"
      key = "${config.sops.secrets.sftp-privkey.path}"
      root = "/backups/restic"
      known_hosts_strategy = "Accept"
      enable_copy = "true"

      [backup]
      git-ignore = true
      no-require-git = true
      no-scan = true
      one-file-system = true

      [forget]
      keep-last = 1
      keep-hourly = 0
      keep-daily = 7
      keep-weekly = 4
      keep-monthly = 1
      keep-yearly = 1
      prune = true
    '';
    storagebox = ''
      [repository]
      repository = "rclone:storagebox:rustic-backup"
      password-file = "${config.sops.secrets.restic-pw.path}"
      cache-dir = "/var/cache/restic/storagebox"

      [backup]
      git-ignore = true
      no-require-git = true
      no-scan = true
      one-file-system = true

      [forget]
      keep-last = 1
      keep-hourly = 0
      keep-daily = 7
      keep-weekly = 4
      keep-monthly = 1
      keep-yearly = 1
      prune = true
    '';
  };

  maintenanceHosts = {
    "logvm" = [ "storagebox" ];
    "ml-home-vm" = [ "home" ];
  };

  resticCommands = lib.mapAttrsToList (
    k: v:
    let
      configFile = pkgs.writeText "rustic-${k}.toml" v;
    in
    pkgs.writeShellScriptBin "rustic-${k}" ''
      export RUSTIC_USE_PROFILE=${configFile}
      ${lib.optionalString (k == "storagebox") ''
        export PATH=${lib.makeBinPath [ pkgs.rclone ]}:$PATH
        export AWS_ACCESS_KEY_ID="$(cat ${config.sops.secrets.restic-s3-access-key.path})"
        export AWS_SECRET_ACCESS_KEY="$(cat ${config.sops.secrets.restic-s3-secret-key.path})"
        export RCLONE_CONFIG_STORAGEBOX_TYPE=s3
        export RCLONE_CONFIG_STORAGEBOX_PROVIDER=Other
        export RCLONE_CONFIG_STORAGEBOX_ENV_AUTH=true
        export RCLONE_CONFIG_STORAGEBOX_ENDPOINT=https://vaults3.zhyi.cc:8443
        export RCLONE_CONFIG_STORAGEBOX_REGION=east-1
        export RCLONE_CONFIG_STORAGEBOX_FORCE_PATH_STYLE=true
        export RCLONE_CONFIG_STORAGEBOX_NO_CHECK_BUCKET=true
      ''}
      exec ${lib.getExe pkgs.rustic} "$@"
    ''
  ) resticRepos;
}
