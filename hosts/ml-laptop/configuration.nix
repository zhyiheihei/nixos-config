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

  lantian.syncthing.storage = "/nix/persistent/media";

  # Host-level override (optional-apps/sunshine.nix is a public module, left
  # untouched): allow browser access to the Sunshine Web UI from LAN / LTNET,
  # otherwise CSRF protection blocks the pairing page.  Comma-separated because
  # the settings option only accepts atom values.
  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.55:47990,https://198.18.0.118:47990,https://ml-laptop.zhyi.cc:47990";

  # 主网络走 NetworkManager（client 默认）。临时有线网卡和 WiFi 均由其接管；
  # 首次安装验收后建议在目标机用 nmcli 把 WiFi 连接配成静态 192.168.0.55，
  # 连接会被持久化到 /etc/NetworkManager/system-connections（client.nix 已
  # 把该目录加入 preservation），无需把密码写进本仓库。

  # Notes 是 bindfs 视图的 Syncthing 管理存储，与作者 client 的 Documents
  # 布局一致；Notes 仓库独立于本仓库。
  fileSystems."/home/zhyi/Documents/Notes" = lib.mkForce {
    device = "/nix/persistent/media/Notes";
    fsType = "fuse.bindfs";
    options = LT.constants.bindfsMountOptions;
  };

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

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };
}
