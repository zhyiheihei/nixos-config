{ inputs, ... }:
final: prev: {
  audio-cpp-cuda = inputs.audio-cpp.packages."${prev.stdenv.hostPlatform.system}".cuda;
  kwin-effects-better-blur-dx =
    inputs.kwin-effects-better-blur-dx.packages."${prev.stdenv.hostPlatform.system}".default;
  markdown-apa7th-docx =
    inputs.markdown-apa7th-docx.packages."${prev.stdenv.hostPlatform.system}".default;
  nixfmt-rs = inputs.nixfmt-rs.packages."${prev.stdenv.hostPlatform.system}".default;
  never-gonna = inputs.never-gonna-rust.packages."${prev.stdenv.hostPlatform.system}".default;
  picoforge = inputs.picoforge.packages."${prev.stdenv.hostPlatform.system}".picoforge;
  wine-tkg = inputs.nix-gaming.packages."${prev.stdenv.hostPlatform.system}".wine-tkg;
  ncps = inputs.ncps.packages."${prev.stdenv.hostPlatform.system}".default.overrideAttrs (old: {
    go = final.go_1_27;
    nativeBuildInputs = map (x: if (x.pname or "") == "go" then final.go_1_27 else x) (
      old.nativeBuildInputs or [ ]
    );
    goModules = old.goModules.overrideAttrs (_: {
      go = final.go_1_27;
    });
    postInstall = (old.postInstall or "") + ''
      mkdir -p $out/bin
      cat > $out/bin/dbmate-ncps <<EOF
        #!${final.runtimeShell}
        case "\$1" in
          up) exec "$out"/bin/ncps migrate up --cache-database-url "\$DATABASE_URL" ;;
          *) echo "dbmate-ncps shim: only 'up' is supported" >&2; exit 1 ;;
        esac
      EOF
      chmod +x $out/bin/dbmate-ncps
    '';
    doCheck = false;
  });
}
