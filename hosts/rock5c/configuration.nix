{
  lib,
  LT,
  pkgs,
  config,
  ...
}:
let
  proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  proxyBypass = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  proxyEnvironment = {
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    NO_PROXY = proxyBypass;
    http_proxy = proxy;
    https_proxy = proxy;
    no_proxy = proxyBypass;
  };
in
{
  imports = [
    ../../nixos/server.nix

    # Phase 1 of the ml-home-vm split migration.  These services stay on the
    # ROCK 5C address until the edge role has been verified and cut over.
    ../../nixos/optional-apps/homepage-dashboard.nix
    ../../nixos/optional-apps/metacubexd.nix
    ../../nixos/hardware/rockchip/accelerator-metrics.nix

    ./hardware-configuration.nix
    ./home-edge.nix
    ./immich-ml.nix
    ./media-apps.nix
  ];

  # Align with opi5p: the NAS exports the media library directly; mount the
  # same share instead of routing media through another host.
  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = [ pkgs.nfs-utils ];

  # 公共模块的 homepage-dashboard 不设 ALLOWED_HOSTS（默认仅 localhost）；
  # 原 homepage-glass 模块用它把域名放行。移除玻璃后这里补上，否则
  # homepage.rock5c.zhyi.cc 的所有 /api 请求会被 Go 服务以 400 拒绝。
  systemd.services.homepage-dashboard.environment.HOMEPAGE_ALLOWED_HOSTS = lib.mkForce (
    "homepage.localhost,homepage.${config.networking.hostName}.zhyi.cc,"
    + "localhost:${LT.portStr.HomepageDashboard},127.0.0.1:${LT.portStr.HomepageDashboard}"
  );

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

  # ROCK 5C carries a Rockchip RK3588S2 SoC (same VPU family as opi5p's
  # RK3588): enable the rockchip jellyfin build with full AV1/HDR decode.
  lantian.jellyfinRockchip.soc = "rk3588";

  # Never scan an empty local directory when the direct NAS mount is absent.
  systemd.services.jellyfin = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    environment = {
      HTTP_PROXY = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
      HTTPS_PROXY = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
      NO_PROXY = lib.mkForce proxyBypass;
      http_proxy = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
      https_proxy = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
      no_proxy = lib.mkForce proxyBypass;
    };
  };

  # Handbrake image pulls and the distributed RKNN worker's model/image
  # downloads go through the same stable router egress. Moved here from
  # media-apps.nix / immich-ml.nix per module-placement-norms §3.
  systemd.services.podman-handbrake.environment = proxyEnvironment;
  systemd.services.podman-immich-machine-learning-rknn.environment = lib.genAttrs (lib.attrNames proxyEnvironment) (k: lib.mkForce proxyEnvironment.${k});

  # Match the onboard GMAC by its permanent address so future driver or probe
  # ordering changes cannot silently move the static LAN configuration.
  systemd.network.links."10-rock5c-lan" = {
    matchConfig.PermanentMACAddress = "e2:dc:47:5e:02:24";
    linkConfig.Name = "lan0";
  };
  systemd.network.networks."10-rock5c-lan" = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.PermanentMACAddress = "e2:dc:47:5e:02:24";
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

  # The common network policy intentionally masks the global wait-online
  # service. This host's NFS media mount must still wait for its physical LAN
  # carrier, so enable systemd's scoped per-interface instance only.
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@lan0.service" ];

  # The SFTP/data chain moved to OPI5P.  Override only this migrated host;
  # other machines retain the author's established backup endpoint.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";

  # ROCK 5C has no reliable RTC. A calendar timer is armed while the clock is
  # still months behind, then fires immediately when time synchronization
  # jumps forward. The global `podman system prune -af` consequently deletes
  # the imported MetaCubeXD and reDroid images before their units can start.
  # Keep the author default globally and disable automatic pruning only here;
  # image cleanup on this appliance is deliberate and manual.
  virtualisation.podman.autoPrune.enable = lib.mkForce false;

  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    # Self-hosted acceleration via hubproxy on tencent (hub.tencent.zhyi.cc,
    # reached over the ZeroTier/LTNET tunnel). daocloud kept as fallback when
    # the tunnel is unreachable. Other registries (gcr/quay/k8s) are pulled
    # explicitly as hub.tencent.zhyi.cc/<registry>/<image>; podman mirrors
    # cannot express hubproxy's /v2/<registry>/ prefix routing, and GHCR
    # rejects anonymous pulls from datacenter IPs.
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.cc"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';
}

