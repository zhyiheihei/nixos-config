{
  lib,
  pkgs,
  ...
}:
let
  image = "localhost/opi03-redroid:android12-h618";
  stateDirectory = "/nix/persistent/var/lib/redroid-opi03";
  imageReady = "${stateDirectory}/.image-ready";
  redroidCheck = pkgs.writeShellApplication {
    name = "opi03-redroid-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.kmod
      pkgs.podman
      pkgs.systemd
      pkgs.util-linux
    ];
    text = builtins.readFile ../../tools/redroid-opi03/verify.sh;
  };
in
{
  imports = [
    ../../nixos/minimal.nix
    ./hardware-configuration.nix
  ];

  # Use DHCP only during bring-up. Mainline Allwinner DT aliases normally
  # produce end0; eth0 is retained here for older naming policy revisions.
  systemd.network.networks."10-opi03-lan" = {
    matchConfig.Name = "end0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  # The installed board is the 4 GiB variant. zram is a safety margin for
  # activation and evaluation; this board must not become a build worker.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Android's bpfloader needs this writable and enabled.  The repository-wide
  # hardening default is irreversible until reboot, so override it declaratively
  # before the first reDroid start rather than trying to repair it at runtime.
  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

  environment.systemPackages = [
    redroidCheck
    # The locally built Android rootfs is transferred as a .tar.zst archive;
    # keep decompression on opi03 while all compilation stays on ml-builder.
    pkgs.zstd
  ];

  virtualisation.oci-containers.containers.redroid = {
    inherit image;
    labels."io.containers.autoupdate" = "local";
    privileged = true;
    # opi03 has no final LAN identity yet.  Keep ADB on loopback and reach it
    # through SSH forwarding; never expose an unauthenticated ADB daemon on WAN.
    ports = [ "127.0.0.1:5555:5555" ];
    volumes = [ "${stateDirectory}/data:/data" ];
    cmd = [
      "androidboot.redroid_gpu_mode=opi03"
      "androidboot.redroid_width=720"
      "androidboot.redroid_height=1280"
      "androidboot.redroid_fps=30"
      "androidboot.redroid_adbd_bind_eth0=1"
      "androidboot.redroid_fake_wifi=1"
      # Initial accelerator bring-up is permissive so SELinux policy noise
      # cannot hide a GPU/VPU ABI error.  Tightening is a separate acceptance
      # step after Mali and c2.allwinner both pass.
      "androidboot.selinux=permissive"
      "ro.adb.secure=0"
      "ro.build.characteristics=default"
    ];
  };

  systemd.tmpfiles.settings.redroid-opi03 = {
    "${stateDirectory}"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    "${stateDirectory}/data"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };

  systemd.services.podman-redroid = {
    # A fresh NixOS image must remain bootable before the locally built Android
    # rootfs has been imported.  The explicit marker turns this into a skipped
    # unit, not a failed activation or an accidental registry pull.
    unitConfig.ConditionPathExists = imageReady;
    preStart = lib.mkBefore ''
      if ! ${pkgs.podman}/bin/podman image exists ${image}; then
        echo "${image} is missing; remove ${imageReady} or import the image" >&2
        exit 1
      fi

      for node in /dev/mali0 /dev/cedar_dev /dev/ion /dev/g2d; do
        if ! test -c "$node"; then
          echo "required H618 accelerator node is missing: $node" >&2
          exit 1
        fi
      done
    '';
  };
}
