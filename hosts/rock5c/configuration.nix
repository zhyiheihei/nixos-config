{
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/minimal.nix

    ./hardware-configuration.nix
  ];

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

  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

  virtualisation.oci-containers.containers.redroid = {
    image = "docker.io/cnflysky/redroid-rk3588:lineage-20";
    labels."io.containers.autoupdate" = "registry";
    privileged = true;
    ports = [ "${LT.this.interconnect.IPv4}:5555:5555" ];
    volumes = [
      "/nix/persistent/var/lib/redroid-rk3588-lineage20:/data"
    ];
    cmd = [
      "androidboot.redroid_width=720"
      "androidboot.redroid_height=1280"
      "androidboot.redroid_fps=60"
      # reDroid is connected through the container's Ethernet interface.
      # Some Android applications only start large downloads on Wi-Fi, so use
      # the image's supported Fake WiFi compatibility layer.
      "androidboot.redroid_fake_wifi=1"
      # Enable the Kitsune Magisk integration bundled with this image.
      "androidboot.redroid_magisk=1"
      # Match the upstream compose example instead of advertising a TV or
      # embedded-device product class to applications.
      "ro.build.characteristics=default"
    ];
  };

  systemd.tmpfiles.settings.redroid."/nix/persistent/var/lib/redroid-rk3588-lineage20"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  systemd.services.podman-redroid = {
    environment = {
      HTTP_PROXY = "http://192.168.0.51:7892";
      HTTPS_PROXY = "http://192.168.0.51:7892";
      NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,docker.m.daocloud.io,.zhyi.cc,.zhyi.xin";
    };
    preStart = lib.mkBefore ''
      install -d -m 0700 -o root -g root /nix/persistent/var/lib/redroid-rk3588-lineage20
      test -c /dev/mali0
    '';
  };

  systemd.services.redroid-landscape-navigation = {
    description = "Configure reDroid landscape display and side navigation bar";
    wantedBy = [ "multi-user.target" ];
    after = [ "podman-redroid.service" ];
    requires = [ "podman-redroid.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 5;
    };
    script = ''
      for attempt in $(${pkgs.coreutils}/bin/seq 1 90); do
        if ${pkgs.podman}/bin/podman exec redroid getprop sys.boot_completed \
          | ${pkgs.gnugrep}/bin/grep -qx 1; then
          ${pkgs.podman}/bin/podman exec redroid wm size reset
          ${pkgs.podman}/bin/podman exec redroid wm user-rotation lock 1
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 2
      done
      echo "reDroid did not finish booting within 180 seconds" >&2
      exit 1
    '';
  };
}
