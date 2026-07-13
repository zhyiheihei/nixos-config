{ ... }:
{
  imports = [
    ./common
    ./core

    ./domains/moliy.site.nix
    ./domains/zhyi.cc.nix
    ./domains/zhyi.xin.nix
  ];

  registrars = [ ];
  providers = [ "gcore" ];
}
