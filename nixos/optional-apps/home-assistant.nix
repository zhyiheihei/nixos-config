{ config, ... }:
{
  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:2026.3.1";
    labels."io.containers.autoupdate" = "registry";
    extraOptions = [
      "--network=host"
      "--privileged"
    ];
    environment.TZ = config.time.timeZone;
    volumes = [
      "/var/lib/home-assistant:/config"
      "/dev:/dev"
      "/etc/localtime:/etc/localtime:ro"
      "/var/run/docker.sock:/var/run/docker.sock"
    ];
  };

  systemd.services.podman-home-assistant = {
    after = [ "podman.socket" ];
    requires = [ "podman.socket" ];
  };

  systemd.tmpfiles.settings.home-assistant."/var/lib/home-assistant"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };
}
