{ config, ... }:
{
  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:2026.3.1";
    extraOptions = [
      "--network=host"
      "--privileged"
    ];
    environment.TZ = config.time.timeZone;
    volumes = [
      "/mnt/storage/homeassistant:/config"
      "/dev:/dev"
      "/etc/localtime:/etc/localtime:ro"
      "/var/run/docker.sock:/var/run/docker.sock"
    ];
  };

  systemd.services.podman-home-assistant = {
    after = [
      "mnt-storage.mount"
      "podman.socket"
    ];
    requires = [
      "mnt-storage.mount"
      "podman.socket"
    ];
  };

  systemd.tmpfiles.settings.home-assistant."/mnt/storage/homeassistant"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };
}
