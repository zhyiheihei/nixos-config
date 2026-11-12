{ lib, ... }:
let
  publicServices = [
    "dav"
  ];
in
{
  lantian.nginxVhosts = lib.genAttrs (map (name: "${name}.zhyi.xin") publicServices) (_: {
  });
}
