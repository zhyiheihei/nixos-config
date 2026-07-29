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

  # Android's bpfloader requires this to remain writable/enabled. The common
  # hardening policy sets it to the irreversible value 1, which cannot be
  # changed back until reboot and makes every official reDroid image shut down.
  # Keep ADB bound to the LAN address; do not expose this host publicly.
  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

  # Early images recorded the build user's ownership on a few persistent
  # filesystem roots. Correct only these roots before tmpfiles validates path
  # transitions; do not recursively alter Nix store or application data.
  system.activationScripts.opi5p-persistent-root-ownership.text = ''
    chown root:root /nix /nix/persistent /nix/var/nix
  '';

  # Mainline experiment: expose the RK3588 Panthor DRM render node to the
  # upstream reDroid image.  Keep the container image out of the immutable
  # system closure; Podman pulls it at runtime and stores persistent Android
  # state on /nix.
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

  virtualisation.oci-containers.containers.redroid = {
    # Use the regular Android 14 image so the arm64 instance retains support
    # for 32-bit Android applications. Android 15+ rejects the current 6.18
    # mainline kernel in bpfloader because it is not on Android's LTS allowlist.
    image = "docker.io/redroid/redroid:14.0.0-latest";
    labels."io.containers.autoupdate" = "registry";
    privileged = true;
    ports = [ "${LT.this.interconnect.IPv4}:5555:5555" ];
    volumes = [
      "/nix/persistent/var/lib/redroid-14:/data"
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

  systemd.tmpfiles.settings.redroid."/nix/persistent/var/lib/redroid-14"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  # The image is large and the board may start before Panthor creates its render
  # node. /dev/dri/renderD128 does not necessarily have a corresponding active
  # systemd .device unit, so wait for the actual node before starting reDroid.
  systemd.services.podman-redroid = {
    environment = {
      HTTP_PROXY = "http://192.168.0.51:7892";
      HTTPS_PROXY = "http://192.168.0.51:7892";
      NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,docker.m.daocloud.io,.zhyi.cc,.zhyi.xin";
      http_proxy = "http://192.168.0.51:7892";
      https_proxy = "http://192.168.0.51:7892";
      no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,docker.m.daocloud.io,.zhyi.cc,.zhyi.xin";
    };
    preStart = lib.mkBefore ''
      install -d -m 0700 -o root -g root /nix/persistent/var/lib/redroid-14

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
