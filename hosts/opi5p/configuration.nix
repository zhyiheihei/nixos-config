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
    # TODO: replace with your actual temporary public key
    # "ssh-ed25519 AAAA... your-key-comment"
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
  # node.  Wait for the device instead of repeatedly starting in software mode.
  systemd.services.podman-redroid = {
    after = [ "dev-dri-renderD128.device" ];
    requires = [ "dev-dri-renderD128.device" ];
    unitConfig.ConditionPathExists = "/dev/dri/renderD128";
  };
}
