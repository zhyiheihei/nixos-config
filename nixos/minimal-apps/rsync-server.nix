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
  lantian.firewall.presets.public-firewall.firewalledPorts = lib.mkIf config.services.rsyncd.enable [
    LT.port.Rsync
  ];

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
        address = LT.this.ltnet.IPv6;
        gid = "root";
        uid = "root";
        "use chroot" = true;
      };

      sections = {
        sync-servers = {
          "read only" = true;
          "hosts allow" = "198.18.0.0/15 fdd8:1938:4e88::/48";
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
    listenStreams = lib.mkForce [ "[${LT.this.ltnet.IPv6}]:${LT.portStr.Rsync}" ];
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
            "--no-group"
            "--delete-after"
            "--timeout=300"
            "rsync://[${LT.hosts.${primaryServer}.ltnet.IPv6}]/sync-servers/"
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
