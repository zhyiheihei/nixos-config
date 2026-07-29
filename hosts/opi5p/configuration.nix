{
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/minimal.nix

    ./hardware-configuration.nix
  ];

  # ── Phase 1: Minimal boot validation ──────────────────────────────
  # Only enable what is needed to validate the boot chain, serial
  # console, network, and SSH access.  Do NOT add production services
  # until Phase 4 gates are passed.

  # Temporary SSH key for initial bring-up.  Remove after formal
  # host keys and SOPS are validated.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAXn2roZsbvURS+faytLLz2OE1gemC19RMNsPj3Ypnha 2386656187@qq.com"
  ];

  # Static network configuration for initial LAN access.
  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  # Bring up the second RTL8125 as well.  A distinct LAN-only rescue address
  # avoids a competing default route while both physical ports are mapped.
  systemd.network.networks.eth1 = {
    address = [ "192.168.0.63/24" ];
    matchConfig.Name = "eth1";
    networkConfig.IPv6AcceptRA = "yes";
  };
  networking.networkmanager.enable = lib.mkForce false;

  # Mainline experiment: expose the RK3588 Panthor DRM render node to the
  # upstream reDroid image.  Keep the container image out of the immutable
  # system closure; Podman pulls it at runtime and stores persistent Android
  # state on /nix.
  virtualisation.oci-containers.containers.redroid = {
    image = "docker.io/redroid/redroid:16.0.0_64only-latest";
    labels."io.containers.autoupdate" = "registry";
    privileged = true;
    ports = [ "${LT.this.interconnect.IPv4}:5555:5555" ];
    volumes = [
      "/nix/persistent/var/lib/redroid:/data"
    ];
    cmd = [
      "androidboot.use_memfd=true"
      "androidboot.redroid_gpu_mode=host"
      "androidboot.redroid_gpu_node=/dev/dri/renderD128"
      "androidboot.redroid_width=1280"
      "androidboot.redroid_height=720"
      "androidboot.redroid_fps=60"
    ];
    extraOptions = [
      "--device=/dev/dri/renderD128"
    ];
  };

  systemd.tmpfiles.settings.redroid."/nix/persistent/var/lib/redroid"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  # The image is large and the board may start before Panthor creates its render
  # node. /dev/dri/renderD128 does not necessarily have a corresponding active
  # systemd .device unit, so wait for the actual node before starting reDroid.
  systemd.services.podman-redroid = {
    preStart = lib.mkBefore ''
      for attempt in $(seq 1 120); do
        if test -e /dev/dri/renderD128; then
          exit 0
        fi
        sleep 1
      done

      echo "Timed out waiting for /dev/dri/renderD128" >&2
      exit 1
    '';
  };
}
