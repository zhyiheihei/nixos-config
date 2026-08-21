{ ... }:
{
  imports = [
    ./common
    ./core

    ./domains/zhyi.xin.nix
    ./domains/zhyi.dn42.nix
    ./domains/dn42-reverse.nix
    ./domains/tel.dn42.nix
  ];

  registrars = [ ];
  providers = [ "bind" "gcore" ];
}
