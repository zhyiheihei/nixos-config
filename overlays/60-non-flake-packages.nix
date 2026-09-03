{ inputs, ... }:
final: prev: {
  never-gonna = inputs.never-gonna-rust.packages."${prev.stdenv.hostPlatform.system}".default;
  nixfmt-rs = inputs.nixfmt-rs.packages."${prev.stdenv.hostPlatform.system}".default;
  ncps = inputs.ncps.packages."${prev.stdenv.hostPlatform.system}".default.overrideAttrs (old: {
    # signature.VerifyFirst rejects a narinfo as soon as the first key with a
    # matching name fails, so our attic and the author's attic (both signing
    # as "lantian") shadow each other and attic-only paths are never served.
    # Rebased against ncps 3a46da66 (the #1329 opaque-URL fix is upstream now);
    # the old FileSize patch is superseded by upstream issue #1314 handling.
    patches = (old.patches or [ ]) ++ [ ../patches/ncps-verify-any-named-key.patch ];
    # The cache-package tests enable Go ThreadSanitizer, which cannot run
    # under qemu-user aarch64 emulation (unsupported VMA range 47/48).
    doCheck = false;
  });
}
