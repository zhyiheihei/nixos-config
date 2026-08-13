{
  config,
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/client.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/syncthing
  ];

  lantian.syncthing.storage = "/nix/persistent/media";

  # Host-level override (optional-apps/sunshine.nix is a public module, left
  # untouched): allow browser access to the Sunshine Web UI from LAN / LTNET,
  # otherwise CSRF protection blocks the pairing page. Comma-separated because
  # the settings option only accepts atom values.
  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.53:47990,https://198.18.0.113:47990,https://ml-2700.zhyi.cc:47990";

  # AMD APU (Vega 3): client-components/xorg.nix sets the Intel default
  # LIBVA_DRIVER_NAME=iHD, which breaks VA-API on this GPU. Override to
  # radeonsi so hardware encoding works.
  environment.variables.LIBVA_DRIVER_NAME = lib.mkForce "radeonsi";

  # Force the mature VA-API hardware encoder. The default h264_vulkan (RADV)
  # produced blocky artifacts on this APU, and vaapi is only probed after
  # vulkan in Sunshine's encoder priority list.
  services.sunshine.settings.encoder = "vaapi";

  # Notes is a bindfs view of the Syncthing-managed storage, matching the
  # author's client Documents layout. The Notes repo stays independent from
  # this repository.
  fileSystems."/home/zhyi/Documents/Notes" = lib.mkForce {
    device = "/nix/persistent/media/Notes";
    fsType = "fuse.bindfs";
    options = LT.constants.bindfsMountOptions;
  };

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  systemd.network.networks.eth1 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    matchConfig.Name = "eth1";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };
}
