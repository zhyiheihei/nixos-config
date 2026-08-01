{
  config,
  pkgs,
  ...
}:
{
  # Trial instance for validating RK3588 transcoding before the public
  # jellyfin.zhyi.xin endpoint is moved away from ml-home-vm.  Jellyfin keeps
  # its own local database; only the media files are read from the NAS.
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    openFirewall = false;

    hardwareAcceleration = {
      enable = true;
      type = "rkmpp";
      device = "/dev/mpp_service";
    };
    forceEncodingConfig = true;
    transcoding = {
      enableHardwareEncoding = true;
      enableToneMapping = true;
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true;
        mpeg2 = true;
        vp8 = true;
        vp9 = true;
        av1 = true;
      };
      # RK3588 can encode H.264 and HEVC; it has no AV1 encoder.
      hardwareEncodingCodecs = {
        hevc = true;
        av1 = false;
      };
    };
  };

  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];

  # Never start against an empty /mnt/storage directory if the NAS mount
  # failed.  This also prevents an accidental library scan from deleting
  # entries in the cloned database.
  systemd.services.jellyfin = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
    environment = {
      HTTP_PROXY = "http://192.168.0.1:1080";
      HTTPS_PROXY = "http://192.168.0.1:1080";
      NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
      JELLYFIN_PublishedServerUrl = "http://${config.networking.hostName}:8096";
    };
    serviceConfig = {
      DeviceAllow = [
        "/dev/mpp_service rw"
        "/dev/rga rw"
        "/dev/dri/renderD128 rw"
        "/dev/dri/renderD129 rw"
        "/dev/dma_heap/system rw"
        "/dev/dma_heap/system-dma32 rw"
        "/dev/dma_heap/system-uncached rw"
        "/dev/dma_heap/system-uncached-dma32 rw"
      ];
    };
  };

  # Trial access is LAN-only.  The production nginx vhost remains exclusively
  # on ml-home-vm until the migration is explicitly approved.
  networking.firewall.interfaces.lan0 = {
    allowedTCPPorts = [ 8096 ];
    allowedUDPPorts = [
      1900
      7359
    ];
  };
}
