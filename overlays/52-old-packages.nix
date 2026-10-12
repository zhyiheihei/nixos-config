{ inputs, ... }:
final: prev:
let
  mv = inputs.nixpkgs-multiverse.multiverse.${final.stdenv.hostPlatform.system};
in
{
  inherit (mv.at "26.05") linphone linphonePackages;

  zerotierone = prev.zerotierone.overrideAttrs (old: rec {
    version = "1.14.2";
    src = final.fetchFromGitHub {
      owner = "zerotier";
      repo = "ZeroTierOne";
      tag = version;
      hash = "sha256-D+7/ja5uYzH1iNd+Ti3k+dWOf5GvN4U+GuVBA9gxtTc=";
    };
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit src;
      sourceRoot = "${src.name}/rustybits";
      hash = "sha256-ADWCWJ5xl1Vl5lj386JBTjXEF6C6k6HkumXHcI4Uy0Q=";
    };
    patches = [ ];
  });
}
