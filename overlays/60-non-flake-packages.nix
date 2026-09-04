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
  # 上游 flake 版 ncps（nixpkgs 0.9.4 不认 attic/cachix 的非 hash NAR URL，
  # kalbasit/ncps#1329）。上游 go.mod 要求 go >= 1.26.6，本仓 nixpkgs 锁在
  # 1.26.5，用 go_1_27 覆盖 go / nativeBuildInputs / goModules。
  # 同名 key 遮蔽问题已由 attic 缓存改名 zhyi（8025ec58）解决，无需补丁。
  ncps = inputs.ncps.packages."${prev.stdenv.hostPlatform.system}".default.overrideAttrs (old: {
    go = final.go_1_27;
    nativeBuildInputs = map (x: if (x.pname or "") == "go" then final.go_1_27 else x) (
      old.nativeBuildInputs or [ ]
    );
    goModules = old.goModules.overrideAttrs (_: {
      go = final.go_1_27;
    });
    # 上游 flake 的包已内嵌迁移（`ncps migrate up`，goose），不再带
    # dbmate-ncps；而 nixpkgs services.ncps 模块的 preStart 仍调用
    # `dbmate-ncps up`（DATABASE_URL 环境变量）。此处加一个等价垫片，
    # 迁移逻辑交给 ncps 自身。
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
    # The cache-package tests enable Go ThreadSanitizer, which cannot run
    # under qemu-user aarch64 emulation (unsupported VMA range 47/48).
    doCheck = false;
  });
}
