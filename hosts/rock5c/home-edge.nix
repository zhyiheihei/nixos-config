{ ... }:
{
  imports = [
    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/vlmcsd.nix

    ./media-edge.nix
  ];
}
