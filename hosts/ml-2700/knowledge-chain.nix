{
  imports = [ ../../nixos/optional-apps/syncthing ];

  home-manager.users.zhyi.imports = [ ./knowledge-chain-home.nix ];
}
