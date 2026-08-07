{
  lib,
  LT,
  ...
}:
{
  imports = [ ../../nixos/optional-apps/immich-rknn-worker.nix ];

  # Distributed Immich RKNN worker on ROCK 5C's RK3588S2 NPU. Cache stays on
  # the local eMMC-backed /nix/persistent; threads are capped at 2 to keep RSS
  # within this 8 GiB board while OPI5P keeps its 3-thread primary worker.
  lantian.immichRknnWorker.enable = true;

  # Route the RKNN worker's model/image downloads through the router SOCKS5
  # proxy instead of ROCK 5C's own MetaCubeXD mixed port.
  systemd.services.podman-immich-machine-learning-rknn.environment = {
    HTTP_PROXY = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    HTTPS_PROXY = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    NO_PROXY = lib.mkForce "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
    http_proxy = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    https_proxy = lib.mkForce "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    no_proxy = lib.mkForce "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  };
}
