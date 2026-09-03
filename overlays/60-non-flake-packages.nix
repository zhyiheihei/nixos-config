{ inputs, ... }:
final: prev: {
  never-gonna = inputs.never-gonna-rust.packages."${prev.stdenv.hostPlatform.system}".default;
  nixfmt-rs = inputs.nixfmt-rs.packages."${prev.stdenv.hostPlatform.system}".default;
  # 上游 flake 版 ncps（nixpkgs 0.9.4 不认 attic/cachix 的非 hash NAR URL，
  # kalbasit/ncps#1329）。上游 go.mod 要求 go >= 1.26.6，本仓 nixpkgs 锁在
  # 1.26.5，用 go_1_27 覆盖 go / nativeBuildInputs / goModules。
  ncps = inputs.ncps.packages."${prev.stdenv.hostPlatform.system}".default.overrideAttrs (old: {
    go = final.go_1_27;
    nativeBuildInputs =
      map (x: if (x.pname or "") == "go" then final.go_1_27 else x) (old.nativeBuildInputs or [ ]);
    goModules = old.goModules.overrideAttrs (_: { go = final.go_1_27; });
    # signature.VerifyFirst rejects a narinfo as soon as the first key with a
    # matching name fails, so our attic and the author's attic (both signing
    # as "lantian") shadow each other and attic-only paths are never served.
    patches = (old.patches or [ ]) ++ [ ../patches/ncps-verify-any-named-key.patch ];
    # The cache-package tests enable Go ThreadSanitizer, which cannot run
    # under qemu-user aarch64 emulation (unsupported VMA range 47/48).
    doCheck = false;
  });
}
