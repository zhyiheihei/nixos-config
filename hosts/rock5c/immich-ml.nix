{ ... }:
{
  imports = [ ../../nixos/optional-apps/immich-rknn-worker.nix ];

  lantian.immichRknnWorker.enable = true;

  virtualisation.oci-containers.containers.immich-machine-learning-rknn.environment.RKNN_LOG_LEVEL =
    "0";
}
