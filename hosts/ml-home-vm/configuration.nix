{
  config,
  inputs,
  LT,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    # ../../nixos/optional-apps/attic-watch-store.nix

    ./hardware-configuration.nix
    ./media-center.nix
    ./shares.nix

    ../../nixos/client-components/cups.nix
    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/archiveteam.nix
    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/axonhub.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/clawemail.nix
    ../../nixos/optional-apps/epic-awesome-gamer
    ../../nixos/optional-apps/excalidraw.nix
    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/filecodebox.nix
    ../../nixos/optional-apps/freshrss.nix
    ../../nixos/optional-apps/glauth.nix
    ../../nixos/optional-apps/handbrake-server.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/homepage-dashboard.nix
    ../../nixos/optional-apps/immich.nix
    ../../nixos/optional-apps/iyuuplus.nix
    ../../nixos/optional-apps/llama-cpp.nix
    ../../nixos/optional-apps/linkwarden.nix
    ../../nixos/optional-apps/metacubexd.nix
    ../../nixos/optional-apps/metapi.nix
    ../../nixos/optional-apps/memos.nix
    ../../nixos/optional-apps/n8n
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/open-webui
    ../../nixos/optional-apps/searxng.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/sun-panel.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/tachidesk.nix
    ../../nixos/optional-apps/uni-api.nix
    ../../nixos/optional-apps/vertex.nix
    ../../nixos/optional-apps/vlmcsd.nix
    ../../nixos/optional-apps/webdav.nix
    ../../nixos/optional-apps/worker-vless2sub.nix

    ../../nixos/optional-cron-jobs/qbittorrent-pt-cleanup
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix

    "${inputs.secrets}/nixos-hidden-module/851e5310ebca4e5c"
  ];

  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ "openclash.zhyi.cc" ];
    "${LT.this.ltnet.IPv4}" = [ "sftp.ml-home-vm.zhyi.cc" ];
    "${LT.hosts.ml-builder.interconnect.IPv4}" = [ "ml-builder.zhyi.cc" ];
    "${LT.hosts."pve-5700u".interconnect.IPv4}" = [ "pve-5700u.zhyi.cc" ];
    # LAN 直连 colocrossing，绕过 hairpin NAT 访问 attic
    "${LT.hosts.colocrossing.interconnect.IPv4}" = [ "attic.zhyi.xin" ];
  };

  environment.systemPackages = with pkgs; [
    age
    attic-client
    sops
    ssh-to-age
  ];

  services.ncps.cache.maxSize = lib.mkForce "50G";

  # Keep the temporary edp-panel database role confined to its own database.
  # These entries must precede the shared LTNET PostgreSQL HBA rules.
  services.postgresql.authentication = lib.mkBefore ''
    host "edp-panel" "edp-panel" 198.18.0.0/15 md5
    host "edp-panel" "edp-panel" fdd8:1938:4e88::/48 md5
    host all "edp-panel" 198.18.0.0/15 reject
    host all "edp-panel" fdd8:1938:4e88::/48 reject
  '';

  services.calibre-cops.libraryPath = "/mnt/storage/Calibre Library";

  services.printing = {
    browsing = true;
    defaultShared = true;
    listenAddresses = [
      "127.0.0.1:631"
      "${LT.this.interconnect.IPv4}:631"
    ];
    allowFrom = [ "all" ];
  };

  lantian.immich.storage = "/mnt/storage/immich";
  lantian.syncthing.storage = "/mnt/storage/media";
  fileSystems."/run/syncthing-files".options = lib.mkAfter [ "_netdev" ];
  lantian.archivebox.storage = "/mnt/storage/archivebox";

  systemd.services.podman-epic-awesome-gamer.serviceConfig.ExecCondition =
    pkgs.writeShellScript "epic-awesome-gamer-credentials-ready" ''
      envFile=${lib.escapeShellArg config.sops.secrets.epic-awesome-gamer-env.path}
      for key in GEMINI_API_KEY EPIC_EMAIL EPIC_PASSWORD; do
        if ! ${lib.getExe pkgs.gnugrep} -q "^$key=." "$envFile"; then
          echo "Skipping epic-awesome-gamer: $key is not configured"
          exit 1
        fi
      done
    '';

  systemd.services.radicale-calendar-sync.serviceConfig = {
    AmbientCapabilities = [ "CAP_DAC_OVERRIDE" ];
    CapabilityBoundingSet = [ "CAP_DAC_OVERRIDE" ];
  };

}
