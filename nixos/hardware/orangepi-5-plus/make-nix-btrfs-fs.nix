{
  pkgs,
  lib,
  storePaths,
  compressImage ? false,
  populateImageCommands ? "",
  volumeLabel,
  uuid ? "55555555-5555-5555-8888-888888888888",
  btrfs-progs,
  libfaketime,
  fakeroot,
  zstd,
}:
# Build the persistent /nix filesystem used by the Orange Pi 5 Plus disk image.
let
  closureInfo = pkgs.buildPackages.closureInfo { rootPaths = storePaths; };
in
pkgs.stdenv.mkDerivation {
  name = "nix-btrfs-fs.img${lib.optionalString compressImage ".zst"}";

  nativeBuildInputs = [
    btrfs-progs
    fakeroot
    libfaketime
  ]
  ++ lib.optional compressImage zstd;

  buildCommand = ''
    ${if compressImage then "img=temp.img" else "img=$out"}

    mkdir -p files
    ${populateImageCommands}

    mkdir -p rootImage/store
    xargs -I % cp -a --reflink=auto % -t rootImage/store/ < ${closureInfo}/store-paths

    shopt -s dotglob nullglob
    for file in files/*; do
      cp -a --reflink=auto "$file" rootImage/
    done

    cp ${closureInfo}/registration rootImage/nix-path-registration

    touch "$img"
    # Run chown and mkfs in the same fakeroot session.  Otherwise mkfs records
    # the sandbox builder's uid/gid in the image, which later makes security
    # checks such as logrotate's reject files from /nix/store.
    fakeroot sh -eu -c '
      chown -R 0:0 rootImage
      faketime -f "1970-01-01 00:00:01" \
        mkfs.btrfs -L ${volumeLabel} -U ${uuid} -r rootImage --shrink "$1"
    ' -- "$img"
    btrfs check "$img"

    ${lib.optionalString compressImage ''
      zstd -v --no-progress "$img" -o "$out"
    ''}
  '';
}
