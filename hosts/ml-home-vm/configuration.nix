{
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
    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/glauth.nix
    ../../nixos/optional-apps/handbrake-server.nix
    ../../nixos/optional-apps/homepage-dashboard.nix
    ../../nixos/optional-apps/immich.nix
    ../../nixos/optional-apps/iyuuplus.nix
    ../../nixos/optional-apps/llama-cpp.nix
    ../../nixos/optional-apps/metapi.nix
    ../../nixos/optional-apps/n8n
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/open-webui
    ../../nixos/optional-apps/searxng.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/tachidesk.nix
    ../../nixos/optional-apps/uni-api.nix
    ../../nixos/optional-apps/vlmcsd.nix
    ../../nixos/optional-apps/webdav.nix
    ../../nixos/optional-apps/worker-vless2sub.nix

    ../../nixos/optional-cron-jobs/qbittorrent-pt-cleanup
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix

    "${inputs.secrets}/nixos-hidden-module/851e5310ebca4e5c"
  ];

  systemd.network.networks.ens18 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "ens18";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts = {
    "192.168.2.116" = [ "openclash.zhyi.cc" ];
    "${LT.hosts.colocrossing.interconnect.IPv4}" = [
      "attic.zhyi.xin"
      "cal.zhyi.xin"
      "element.zhyi.xin"
      "git.zhyi.xin"
      "hydra.zhyi.cc"
      "id.zhyi.xin"
      "login.zhyi.xin"
      "netbox.zhyi.cc"
      "posts.zhyi.xin"
      "rss.zhyi.xin"
      "stats.zhyi.xin"
      "tools.zhyi.xin"
    ];
    "${LT.hosts.ml-builder.interconnect.IPv4}" = [ "ml-builder.zhyi.cc" ];
  };

  environment.systemPackages = with pkgs; [
    age
    attic-client
    sops
    ssh-to-age
  ];

  services.ncps.cache.maxSize = lib.mkForce "50G";

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
  lantian.archivebox.storage = "/mnt/storage/archivebox";

  systemd.services.radicale-calendar-sync.serviceConfig = {
    AmbientCapabilities = [ "CAP_DAC_OVERRIDE" ];
    CapabilityBoundingSet = [ "CAP_DAC_OVERRIDE" ];
  };

}
