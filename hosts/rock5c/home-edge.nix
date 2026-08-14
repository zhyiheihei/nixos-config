{ ... }:
{
  imports = [
    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/glauth.nix
    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/vlmcsd.nix

    ./app-edge.nix
    ./home-lan-edge.nix
    ./media-edge.nix
  ];
}
