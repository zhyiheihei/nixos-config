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

    ./wireplumber-disable-hdmi-audio.nix
    # ./xvcd.nix

    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/pipewire-combined-sink-alsa.nix
    # ../../nixos/optional-apps/pipewire-network-audio-receive.nix
    ../../nixos/optional-apps/pipewire-roc-source.nix
    ../../nixos/optional-apps/pipewire-vban-recv.nix
    ../../nixos/optional-apps/pipewire-volume-control.nix
    ../../nixos/optional-apps/syncthing
    # ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/leigod-accelerator.nix
  ];

  lantian.backup = {
    enable = true;
    resticRepos = [ "home" ];
    paths = {
      nix-persistent = lib.mkForce {
        snapshotFrom = "/nix";
        snapshotTo = "/nix/.snapshot";
        backupPath = "/nix/.snapshot/persistent";
      };
      home = {
        snapshotFrom = "/nix";
        snapshotTo = "/nix/.snapshot-home";
        backupPath = "/nix/.snapshot-home/persistent/home/zhyi";
        ignored = ''
          .cache
          .cursor/extensions
          .local/share/containers
          .local/share/Steam/steamapps/common
          .local/share/Xilinx
          .vscode/extensions
          .windsurf/extensions
          Downloads
        '';
      };
    };
    schedule = "daily";
    persistentTimer = true;
  };

  lantian.crow-translate.enable = true;

  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.53:47990,https://198.18.0.113:47990,https://ml-2700.zhyi.xin:47990";

  environment.variables.LIBVA_DRIVER_NAME = lib.mkForce "radeonsi";

  systemd.user.services.sunshine.environment.LIBVA_DRIVER_NAME = "radeonsi";

  services.sunshine.settings.encoder = "vaapi";

  systemd.network.netdevs.bond0 = {
    netdevConfig = {
      Kind = "bond";
      Name = "bond0";

      MACAddress = "1c:83:41:29:62:48";
    };
    bondConfig = {

      Mode = "balance-xor";
      TransmitHashPolicy = "layer3+4";
      MIIMonitorSec = "100ms";
    };
  };

  systemd.network.networks.eth0 = {
    matchConfig.PermanentMACAddress = "1c:83:41:29:62:47";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.eth1 = {
    matchConfig.PermanentMACAddress = "1c:83:41:29:62:48";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.bond0 = {
    matchConfig.Name = "bond0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    dns = [ "192.168.0.1" ];
    domains = [ "zhyi.xin" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };

  networking.networkmanager.enable = lib.mkForce false;

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

  systemd.units."mnt-share.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
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
