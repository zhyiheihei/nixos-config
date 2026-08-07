{
  lib,
  LT,
  pkgs,
  ...
}:
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
      http_proxy = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
      https_proxy = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    };
  };

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
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

}
