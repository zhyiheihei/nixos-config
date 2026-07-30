{
  lib,
  LT,
  pkgs,
  ...
}:
let
  stateDirectory = "/nix/persistent/var/lib/redroid-rk3588-lineage20";
in
{
  # Android's bpfloader requires this to remain writable/enabled. The common
  # hardening policy sets it to the irreversible value 1.
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
    volumes = [ "${stateDirectory}:/data" ];
    cmd = [
      # Define a portrait-native panel, then rotate it below. Android will
      # render at 1280x720 while SystemUI uses its landscape side navbar.
      "androidboot.redroid_width=720"
      "androidboot.redroid_height=1280"
      "androidboot.redroid_fps=60"
    ];
  };

  systemd.tmpfiles.settings.redroid.${stateDirectory}."d" = {
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
      install -d -m 0700 -o root -g root ${stateDirectory}

      if ! test -c /dev/mali0; then
        echo "RK3588 Mali CSF device /dev/mali0 is unavailable" >&2
        exit 1
      fi
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
