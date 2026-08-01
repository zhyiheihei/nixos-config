{ pkgs, ... }:
{
  # Device permissions for the Rockchip VPU (MPP), 2D blitter (RGA) and
  # dma-heap nodes, following the Jellyfin RK3588 hardware-acceleration guide.
  services.udev.extraRules = ''
    KERNEL=="mpp_service", MODE="0660", GROUP="video"
    KERNEL=="rga", MODE="0660", GROUP="video"
    KERNEL=="system", MODE="0666", GROUP="video"
    KERNEL=="system-dma32", MODE="0666", GROUP="video"
    KERNEL=="system-uncached", MODE="0666", GROUP="video"
    KERNEL=="system-uncached-dma32", MODE="0666", GROUP="video"
    RUN+="${pkgs.coreutils}/bin/chmod a+rw /dev/dma_heap"
  '';
}
