{ ... }:
{
  imports = [
    ./common
    ./core

    ./domains/zhyi.cc.nix
  ];

  registrars = [ ];
  providers = [ "gcore" ];
}
