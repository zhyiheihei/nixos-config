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
    ../../nixos/optional-apps/homepage.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/pipewire-combined-sink-alsa.nix
    ../../nixos/optional-apps/pipewire-roc-source.nix
    ../../nixos/optional-apps/pipewire-vban-recv.nix
    ../../nixos/optional-apps/pipewire-volume-control.nix
    ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/syncthing
  ];

  # Bind mounts
  fileSystems = {
    # keep-sorted start block=yes
    "/home/zhyi/.local/share/ManosabaMod" = lib.mkForce {
      device = "/nix/persistent/media/ManosabaMod";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/.local/share/yuzu" = lib.mkForce {
      device = "/nix/persistent/media/Yuzu";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Backups" = lib.mkForce {
      device = "/nix/persistent/media/Backups";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Books" = lib.mkForce {
      device = "/nix/persistent/media/Books";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Calibre Library" = lib.mkForce {
      device = "/nix/persistent/media/Calibre Library";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Documents" = lib.mkForce {
      device = "/nix/persistent/media/Documents";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/LegacyOS" = lib.mkForce {
      device = "/nix/persistent/media/LegacyOS";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Music/CloudMusic" = lib.mkForce {
      device = "/nix/persistent/media/CloudMusic";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Music/CloudMusicArchive" = lib.mkForce {
      device = "/nix/persistent/media/CloudMusicArchive";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Pictures" = lib.mkForce {
      device = "/nix/persistent/media/Pictures";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Secrets" = lib.mkForce {
      device = "/nix/persistent/media/Secrets";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Software" = lib.mkForce {
      device = "/nix/persistent/media/Software";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Videos/VideoArchive" = lib.mkForce {
      device = "/nix/persistent/media/VideoArchive";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    # keep-sorted end
  };

  # Host-level override (optional-apps/sunshine.nix is a public module, left
  # untouched): allow browser access to the Sunshine Web UI from LAN / LTNET,
  # otherwise CSRF protection blocks the pairing page. Comma-separated because
  # the settings option only accepts atom values.
  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.53:47990,https://198.18.0.113:47990,https://ml-2700.zhyi.cc:47990";

  # AMD APU (Vega 3): client-components/xorg.nix sets the Intel default
  # LIBVA_DRIVER_NAME=iHD, which breaks VA-API on this GPU. Override to
  # radeonsi so hardware encoding works.
  environment.variables.LIBVA_DRIVER_NAME = lib.mkForce "radeonsi";

  # The running user session inherited iHD at login, so /etc/environment alone
  # won't reach the sunshine user unit until the next login. Pin the variable
  # on the unit itself so it applies on restart.
  systemd.user.services.sunshine.environment.LIBVA_DRIVER_NAME = "radeonsi";

  # Force the mature VA-API hardware encoder. The default h264_vulkan (RADV)
  # produced blocky artifacts on this APU, and vaapi is only probed after
  # vulkan in Sunshine's encoder priority list.
  services.sunshine.settings.encoder = "vaapi";
  # NFS share from the fork's file server (opi5p), mirroring the author's
  # client mount of lt-home-vm:/storage. Auto-mounted, non-blocking.
  fileSystems."/mnt/share" = {
    device = "${LT.hosts.opi5p.ltnet.IPv4}:/storage";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "noauto"
      "clientaddr=${LT.this.ltnet.IPv4}"
      "hard"
      "vers=4.2"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=5s"
    ];
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
