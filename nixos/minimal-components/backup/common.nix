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
      endpoint = "ssh://${config.lantian.backup.sftpEndpoint}:2222"
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
      keep-hourly = 1
      keep-daily = 14
      keep-weekly = 8
      keep-monthly = 12
      keep-yearly = 1
      prune = true
    '';
    storagebox = ''
      [repository]
      repository = "opendal:sftp"
      password-file = "${config.sops.secrets.restic-pw.path}"
      cache-dir = "/var/cache/restic/storagebox"

      [repository.options]
      # 异地第二备份目的地。2026-08-31 起家庭出口到 greencloud-jp 公网 IP
      # (45.159.48.76) 的 TCP 全端口被丢（ICMP/UDP 通，典型跨境 QoS），
      # 故改走 LTNET 内网域名（全部备份客户端均可解析，见 dns/domains/）。
      # 公网路径恢复后若要恢复双平面独立，可改回 ssh://greencloud-jp.zhyi.xin:2222。
      user = "sftp"
      endpoint = "ssh://greencloud-jp.ltnet.zhyi.xin:2222"
      key = "${config.sops.secrets.sftp-privkey.path}"
      root = "/backups/rustic-storagebox"
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
  };

  maintenanceHosts = {
    "opi5p" = [ "home" ];
    "greencloud-jp" = [ "storagebox" ];
  };

  resticCommands = lib.mapAttrsToList (
    k: v:
    let
      configFile = pkgs.writeText "rustic-${k}.toml" v;
    in
    pkgs.writeShellScriptBin "rustic-${k}" ''
      export RUSTIC_USE_PROFILE=${configFile}
      exec ${lib.getExe pkgs.rustic} "$@"
    ''
  ) resticRepos;
}
