{ ... }:
{
  imports = [ ../../nixos/optional-apps/immich-rknn-worker.nix ];

  # Distributed Immich RKNN worker on ROCK 5C's RK3588S2 NPU. Cache stays on
  # the local eMMC-backed /nix/persistent; threads are capped at 2 to keep RSS
  # within this 8 GiB board while OPI5P keeps its 3-thread primary worker.
  lantian.immichRknnWorker.enable = true;
}
