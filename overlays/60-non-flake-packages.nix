{ inputs, ... }:
final: prev: {
  dn42-peerfinder = final.callPackage ../pkgs/dn42-peerfinder { };
  lantian-secrets = final.callPackage ../pkgs/lantian-secrets { };
  markdown-apa7th-docx =
    inputs.markdown-apa7th-docx.packages."${prev.stdenv.hostPlatform.system}".default;
  nixfmt-rs = inputs.nixfmt-rs.packages."${prev.stdenv.hostPlatform.system}".default;
  never-gonna = inputs.never-gonna-rust.packages."${prev.stdenv.hostPlatform.system}".default;
  picoforge = inputs.picoforge.packages."${prev.stdenv.hostPlatform.system}".picoforge;
  port-audit = final.callPackage ../pkgs/port-audit { };
  venus-extra-modules = final.callPackage ../pkgs/venus-extra-modules { };
  venus-firmware = final.callPackage ../pkgs/venus-firmware { };
  venus-kernel = final.callPackage ../pkgs/venus-kernel {
    venusMainline = inputs.venus-mainline;
  };
  web-compressor = final.callPackage ../pkgs/web-compressor { };
  wine-tkg = inputs.nix-gaming.packages."${prev.stdenv.hostPlatform.system}".wine-tkg;
}
