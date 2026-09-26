{ ... }:
{
  imports = [
    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/memos-nix.nix
    ../../nixos/optional-apps/wallos.nix
  ];

  lantian.archivebox.storage = "/mnt/storage/archivebox";

  lantian.memos.storage = "/nix/persistent/srv/memos";
  lantian.wallos.storage = "/nix/persistent/srv/wallos";

  lantian.wallos.enable = true;
}
