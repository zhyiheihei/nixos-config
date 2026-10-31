{
  lib,
  pkgs,
  ...
}:
let
  image = "localhost/opi03-redroid:android12-h618";
  stateDirectory = "/nix/persistent/var/lib/redroid-opi03";
  imageReady = "${stateDirectory}/.image-ready";
in
{
  imports = [
    ../../nixos/minimal.nix
    ../../nixos/optional-apps/ncps-client.nix
    ./hardware-configuration.nix
  ];

  systemd.network.networks."10-opi03-lan" = {
    matchConfig.Name = "end0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

  environment.systemPackages = [

    pkgs.zstd
  ];

  virtualisation.oci-containers.containers.redroid = {
    inherit image;
    labels."io.containers.autoupdate" = "local";
    privileged = true;

    ports = [ "127.0.0.1:5555:5555" ];
    volumes = [ "${stateDirectory}/data:/data" ];
    cmd = [
      "androidboot.redroid_gpu_mode=opi03"
      "androidboot.redroid_width=720"
      "androidboot.redroid_height=1280"
      "androidboot.redroid_fps=30"
      "androidboot.redroid_adbd_bind_eth0=1"
      "androidboot.redroid_fake_wifi=1"

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
