_: final: prev:
let
  sources = final.callPackage ../helpers/_sources/generated.nix { };
in
rec {
  # keep-sorted start block=yes
  colmena = prev.colmena.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/colmena-combine-logs-same-node.patch
      ../patches/colmena-verbose-single-node.patch
    ];
  });
  dex-oidc = prev.dex-oidc.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/dex-glob-match-redirect-uri.patch
      ../patches/dex-skip-approval-screen.patch
    ];
    vendorHash = "sha256-7T4svxdzKsSQup1Ls43bK+l/xMgxL4mmQQ7Ck3WoKRk=";
    doCheck = false;
  });
  filezilla = prev.filezilla.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/filezilla-override-pasv-ip-for-zero-ip.patch ];
  });
  handbrake = prev.handbrake.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
    postFixup = ''
      for F in $out/bin/*; do
        wrapProgram "$F" \
          --suffix LD_LIBRARY_PATH : "/run/opengl-driver/lib"
      done
    '';
  });
  hydra = prev.hydra.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/hydra-protect-private-project.patch ];
  });
  # Systemd socket activation support, from https://github.com/esnet/iperf/pull/1171
  iperf3 = prev.iperf3.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/iperf3-socket-activation.patch ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.autoreconfHook ];
    buildInputs = (old.buildInputs or [ ]) ++ [ final.systemdMinimal ];
  });
  knot-dns = prev.knot-dns.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/knot-disable-semantic-check.patch ];
    doCheck = false;
  });
  lemmy-server = prev.lemmy-server.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/lemmy-disable-specific-error.patch ];
  });
  matrix-synapse = prev.matrix-synapse.override { inherit matrix-synapse-unwrapped; };
  matrix-synapse-unwrapped = prev.matrix-synapse-unwrapped.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/matrix-synapse-listen-unix.patch ];
    doCheck = false;
    doInstallCheck = false;
  });
  mpv-unwrapped = prev.mpv-unwrapped.override {
    inherit (final.nur-xddxdd.lantianCustomized) ffmpeg;
  };
  n8n = prev.n8n.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/n8n-17954-openai-compatible-reranker.patch ];
    # nixpkgs pin 的 n8n 2.31.4 tarball 与 pnpmDeps hash 均与现网不符（hash mismatch）。
    # 局部覆盖为现网递归 hash，避免升级整个 nixpkgs 破坏缓存命中。
    src = old.src.overrideAttrs (oldSrc: {
      outputHash = "sha256-lmkCT1o5LSC1ORd+Jozr9hkJu2znMpFO97jTWYOnga0=";
    });
    pnpmDeps = old.pnpmDeps.overrideAttrs (oldPnpm: {
      outputHash = "sha256-ejJ0ihsLdIXbNllDtoi7Yd1u4x61Czxm6d8zJ9Fj7p8=";
    });
  });
  netavark = prev.netavark.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/netavark-disable-conntrack.patch ];
    doCheck = false;
  });
  open-webui = prev.open-webui.overridePythonAttrs (old: {
    dependencies = (old.dependencies or [ ]) ++ old.optional-dependencies.all;
  });
  open5gs = prev.open5gs.overrideAttrs (_old: {
    inherit (sources.open5gs) version src;
    diameter = sources.open5gs-freediameter.src;
  });
  phpWithExtensions = prev.php.withExtensions (
    { enabled, all }:
    with all;
    enabled
    ++ [
      apcu
      bz2
      ctype
      curl
      dom
      event
      exif
      ffi
      ftp
      gd
      gettext
      gmp
      iconv
      imagick
      maxminddb
      mbstring
      memcached
      mysqli
      mysqlnd
      openssl
      pdo
      pdo_mysql
      pdo_pgsql
      pdo_sqlite
      pgsql
      protobuf
      readline
      redis
      sockets
      sodium
      sqlite3
      xml
      yaml
      zip
      zlib
    ]
  );
  prismlauncher = prev.prismlauncher.override {
    jdks =
      (with final; [
        openjdk8
        openjdk11
        openjdk17
      ])
      ++ (with final.nur-xddxdd.openj9-ibm-semeru; [
        jdk-bin-11
        jdk-bin-17
        jdk-bin-8
      ]);
  };
  qbittorrent-enhanced-nox = prev.qbittorrent-enhanced-nox.overrideAttrs (old: {
    # Sonarr retries with different release when adding existing torrent
    patches = (old.patches or [ ]) ++ [ ../patches/qbittorrent-return-success-on-dup-torrent.patch ];
  });
  qbittorrent-nox = prev.qbittorrent-nox.overrideAttrs (old: {
    # Sonarr retries with different release when adding existing torrent
    patches = (old.patches or [ ]) ++ [ ../patches/qbittorrent-return-success-on-dup-torrent.patch ];
  });
  radicle-node = prev.radicle-node.overrideAttrs (old: {
    # Radicle check fails with HPN SSH
    doCheck = false;
  });
  ulauncher = prev.ulauncher.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ (with prev; [ gobject-introspection ]);

    propagatedBuildInputs =
      with prev.python3Packages;
      old.propagatedBuildInputs
      ++ [
        # keep-sorted start
        faker
        fuzzywuzzy
        pint
        pytz
        simpleeval
        # keep-sorted end
      ];
  });
  yt-dlp = prev.yt-dlp.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      # Modified from https://github.com/yt-dlp/yt-dlp/issues/14498#issuecomment-3391106164
      ../patches/yt-dlp-replace-bilibili-hostname.patch
    ];
  });
  zerotierone = prev.zerotierone.override {
    enableUnfree = true;
  };
  # keep-sorted end
}
