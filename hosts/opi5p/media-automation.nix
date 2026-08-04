{
  config,
  lib,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  tachideskActivationMarker = "/nix/persistent/var/lib/media-automation/tachidesk-ready";
  vertexActivationMarker = "/nix/persistent/var/lib/media-automation/vertex-ready";
  mediaGatedServices = [
    "bitmagnet-dht"
    "bitmagnet-http"
    "bitmagnet-queue"
    "flexget-runner"
    "iyuuplus"
    "jproxy"
    "peerbanhelper"
    "podman-byparr"
    "qbittorrent"
    "qbittorrent-pt"
    "qbittorrent-pt-cleanup"
    "qbittorrent-seedbox"
  ];
  gatedServices = mediaGatedServices ++ [
    "podman-tachidesk"
    "podman-vertex"
  ];
  proxiedServices = [
    "bitmagnet-dht"
    "bitmagnet-http"
    "bitmagnet-queue"
    "flexget-runner"
    "iyuuplus"
    "podman-tachidesk"
    "podman-vertex"
  ];
  proxyEnvironment = lib.getAttrs [
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "NO_PROXY"
    "http_proxy"
    "https_proxy"
    "no_proxy"
  ] config.environment.variables;
in
{
  imports = [ ./media-download-chain.nix ];

  # The old and new download stacks must never write the same NFS paths at
  # once.  Deploy all packages, units, users, secrets and databases first, but
  # keep every writer stopped until the state transfer has completed.
  systemd.services = lib.mkMerge [
    (lib.genAttrs mediaGatedServices (_: {
      partOf = [ "media-automation.target" ];
      unitConfig.ConditionPathExists = activationMarker;
    }))
    # OPI5P's direct route to GitHub, TMDB and scene-mapping APIs is
    # intermittent or geo-blocked. Reuse the host's declared outbound proxy
    # for metadata/indexer traffic while LAN and project domains stay direct
    # through NO_PROXY. Torrent peer traffic is intentionally unaffected.
    (lib.genAttrs proxiedServices (_: {
      environment = proxyEnvironment;
    }))
    # Tachidesk has its own cutover marker. The rest of the media stack is
    # already live, so a configuration deployment must not start a fresh
    # empty instance before its SQLite database and library are copied.
    {
      podman-tachidesk = {
        partOf = [ "media-automation.target" ];
        unitConfig.ConditionPathExists = tachideskActivationMarker;
      };
      podman-vertex = {
        partOf = [ "media-automation.target" ];
        unitConfig.ConditionPathExists = vertexActivationMarker;
      };
      # Sonarr/Radarr/Prowlarr now run on rock5c; keep jproxy alive here but
      # stop requiring the moved units. FlexGet follows the same Prowlarr hop.
      jproxy = {
        after = lib.mkForce [ "network.target" ];
        requires = lib.mkForce [ "network.target" ];
      };
      flexget-runner.environment.PROWLARR_URL = lib.mkForce "https://prowlarr.rock5c.zhyi.cc";
    }
  ];
  systemd.timers = lib.genAttrs [
    "flexget-runner"
    "qbittorrent-pt-cleanup"
  ] (_: {
    partOf = [ "media-automation.target" ];
    unitConfig.ConditionPathExists = activationMarker;
  });

  systemd.targets.media-automation = {
    description = "OPI5P media download and automation stack";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices ++ [
      "flexget-runner.timer"
      "qbittorrent-pt-cleanup.timer"
    ];
    after = [
      "mnt-storage.mount"
      "mysql.service"
      "postgresql.service"
    ];
  };

  systemd.tmpfiles.settings.media-automation = {
    "/nix/persistent/var/lib/media-automation".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    # Bitmagnet's 16 GiB PostgreSQL database is write-heavy.  Set NOCOW while
    # the directory is still empty, before PostgreSQL initializes it on NVMe.
    "/nix/persistent/var/lib/postgresql" = {
      d = {
        mode = "0700";
        user = "postgres";
        group = "postgres";
      };
      h.argument = "+C";
    };
  };

  # Public TLS remains on rock5c with the rest of the home edge. Expose a
  # private HTTP-only backend here so the edge never loops through public DNS.
  lantian.nginxVhosts."tachidesk-backend.opi5p.zhyi.cc" = {
    listenHTTP.enable = true;
    listenHTTPS.enable = false;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Tachidesk}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    accessibleBy = "private";
    noIndex.enable = true;
  };

  # The public name is served only by the rock5c edge.
  lantian.tachidesk.publicFrontend = false;
}
