{ ... }:
{
  imports = [ ../../nixos/optional-apps/immich-rknn-worker.nix ];

  # Distributed Immich RKNN worker on ROCK 5C's RK3588S2 NPU. Cache stays on
  # the local eMMC-backed /nix/persistent; threads are capped at 2 to keep RSS
  # within this 8 GiB board while OPI5P keeps its 3-thread primary worker.
  lantian.immichRknnWorker.enable = true;

  # librknnrt logs a harmless "static shape type" warning on every RKNN model
  # load. Level 0 keeps real E RKNN errors while silencing that W RKNN noise.
  # The worker's model/image downloads are proxied via the router SOCKS5
  # endpoint defined in configuration.nix.
  virtualisation.oci-containers.containers.immich-machine-learning-rknn.environment.RKNN_LOG_LEVEL = "0";
}
