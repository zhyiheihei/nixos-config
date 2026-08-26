{ LT, ... }:
{
  imports = [
    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/filecodebox.nix
    ../../nixos/optional-apps/memos-nix.nix
    ../../nixos/optional-apps/sun-panel.nix
    ../../nixos/optional-apps/wallos.nix
  ];

  # ArchiveBox 数据在 NAS 上，dragon-q8b 挂载同一个 NFS share。
  lantian.archivebox.storage = "/mnt/storage/archivebox";

  # 轻量服务数据放本地持久盘。
  lantian.memos.storage = "/nix/persistent/srv/memos";
  lantian.wallos.storage = "/nix/persistent/srv/wallos";
  lantian.sunPanel.storage = "/nix/persistent/srv/sun-panel";
  lantian.filecodebox.storage = "/nix/persistent/srv/filecodebox";

  lantian.wallos.enable = true;
}
