{ ... }:
{
  imports = [
    ./common
    ./core

    ./domains/zhyi.cc.nix
  ];

  registrars = [
    "doh"
    "porkbun"
  ];
  providers = [
    "bind"
    "cloudflare"
    "desec"
    "gcore"
    "henet"
  ];
}
