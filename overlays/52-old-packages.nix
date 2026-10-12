{ inputs, ... }:
final: prev:
let
  mv = inputs.nixpkgs-multiverse.multiverse.${final.stdenv.hostPlatform.system};
  pinned = inputs.nixpkgs-multiverse.lib.mkMultiverse {
    inherit (final.stdenv.hostPlatform) system;
    config = {
      inherit (final.config) allowUnfree allowUnfreePackages;
    };
  };
in
{
  inherit (mv.at "26.05") linphone linphonePackages;
  inherit (pinned.solvePins { zerotierone = "1.14.2"; }) zerotierone;
}
