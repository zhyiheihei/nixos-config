{ ... }:
{
  imports = [
    ./common
    ./core

    ./domains/moliy.site.nix
    ./domains/zhyi.cc.nix
    ./domains/zhyi.xin.nix
    ./domains/zhyi.dn42.nix
    ./domains/dn42-reverse.nix
    ./domains/public-reverse.nix
    ./domains/tel.dn42.nix
  ];

  registrars = [ ];
  providers = [ "gcore" ];
}
