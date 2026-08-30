{
  pkgs,
  lib,
  LT,
  config,
  ...
}:
let
  primaryServer = "greencloud";
in
{
  systemd.tmpfiles.settings = {
    sync-servers = {
      "/nix/sync-servers".d = {
        mode = "755";
        user = "root";
        group = "root";
      };
    };
  };

  ########################################
  # Server
  ########################################

  services.rsyncd = {
    enable = config.networking.hostName == primaryServer;
    port = LT.port.Rsync;
    socketActivated = true;
    settings = {
      globalSection = {
        address = LT.this.ltnet.IPv4;
        gid = "root";
        uid = "root";
        "use chroot" = true;
      };

      sections = {
        sync-servers = {
          "read only" = true;
          "hosts allow" = "198.18.0.0/15";
          path = "/nix/sync-servers";
        };
      };
    };
  };

  systemd.services.rsync.serviceConfig = LT.serviceHarden // {
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    ReadOnlyPaths = [ "/nix/sync-servers" ];
  };

  systemd.sockets.rsync = {
    listenStreams = lib.mkForce [ "${LT.this.ltnet.IPv4}:${LT.portStr.Rsync}" ];
    socketConfig = {
      FreeBind = true;
      SocketProtocol = "mptcp";
    };
  };

  ########################################
  # Client
  ########################################

  systemd.services.rsync-nix-sync-servers = {
    serviceConfig = LT.serviceHarden // {
      Type = "oneshot";
      BindPaths = [ "/nix/sync-servers" ];
      ExecStart =
        if config.networking.hostName != primaryServer then
          builtins.concatStringsSep " " [
            (lib.getExe pkgs.rsync)
            "-aczrq"
            # 源端部分文件组非 root（如 ltnet-registry root:nginx），客户端沙箱
            # 无 CAP_CHOWN 会对每个新文件 chgrp EPERM → exit 23（首次全量同步
            # 必现，2026-08-30 opi5p 实证）。组信息对消费方无意义，不保留。
            "--no-group"
            "--delete-after"
            "--timeout=300"
            "rsync://${LT.hosts.${primaryServer}.ltnet.IPv4}/sync-servers/"
            "/nix/sync-servers/"
          ]
        else
          # For primary server, do not run sync, but still run reload
          (lib.getExe' pkgs.coreutils "true");
    };

    path = [ pkgs.rsync ];

    postStart = ''
      set -x
    ''
    + (lib.optionalString config.services.nginx.enable ''
      systemctl reload nginx.service || true
    '')
    + (lib.optionalString config.services.pdns-recursor.enable ''
      systemctl reload pdns-recursor.service || true
    '')
    + (lib.optionalString config.services.knot.enable ''
      systemctl reload knot.service || true
    '');
  };

  systemd.timers.rsync-nix-sync-servers = {
    enable = config.networking.hostName != primaryServer;
    wantedBy = [ "timers.target" ];
    partOf = [ "rsync-nix-sync-servers.service" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      RandomizedDelaySec = "10min";
      Unit = "rsync-nix-sync-servers.service";
    };
  };
}
