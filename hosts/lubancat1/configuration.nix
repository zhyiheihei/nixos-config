{
  lib,
  LT,
  pkgs,
  ...
}:
let
  # MoviePilot traffic (GitHub plugin repos, TMDB, site sync) egresses via
  # the router proxy like the docker variant on rock5c; socks5h keeps DNS on
  # the proxy so GitHub/plugin lookups work.
  moviepilotProxy = "socks5h://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  moviepilotBypass = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
in
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/moviepilot-nix.nix
    ./hardware-configuration.nix
  ];

  # MoviePilot as a Nix package (not the docker variant): backend + node
  # frontend managed directly by systemd.  Test deployment on this low-ram
  # board; data persists under /nix/persistent.
  lantian.moviepilotNix.enable = true;

  systemd.services.moviepilot-backend.serviceConfig.Environment = [
    "HTTP_PROXY=${moviepilotProxy}"
    "HTTPS_PROXY=${moviepilotProxy}"
    "NO_PROXY=${moviepilotBypass}"
    "http_proxy=${moviepilotProxy}"
    "https_proxy=${moviepilotProxy}"
    "no_proxy=${moviepilotBypass}"
  ];

  lantian.nginxVhosts."moviepilot.lubancat1.zhyi.cc" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    sslCertificate = "zerossl-lubancat1.zhyi.cc";
    noIndex.enable = true;
    accessibleBy = "private";
  };

  # The first-boot DHCP inventory is complete. Keep the board outside the
  # router's dynamic .100-.249 pool and use the same static LAN layout as the
  # other physical infrastructure hosts.
  systemd.network.networks."10-lubancat1-lan" = {
    matchConfig.Name = "eth0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };

  networking.networkmanager.enable = lib.mkForce false;

  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; keep the
  # author's backup semantics by pointing the endpoint at the migrated host.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";

  # Media library + download chain live on the NAS (same direct NFS mount as
  # rock5c used for the docker MoviePilot); MoviePilot needs it for downloads
  # and library imports.
  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = [ pkgs.nfs-utils ];
  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "hard"
      "vers=4.1"
      "nconnect=16"
    ];
  };

  systemd.services.moviepilot-backend = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
  };
}
