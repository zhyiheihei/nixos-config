{ lib, ... }:
let
  publicServices = [
    "asf"
    "books"
    "dav"
    "openlist"
  ];
in
{
  lantian.nginxVhosts = lib.genAttrs (map (name: "${name}.zhyi.xin") publicServices) (_: {
    accessibleBy = lib.mkForce "public";
  });
}
