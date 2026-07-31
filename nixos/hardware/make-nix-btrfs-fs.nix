{
  pkgs,
  lib,
  storePaths,
  compressImage ? false,
  populateImageCommands ? "",
  volumeLabel,
  uuid,
  btrfs-progs,
  libfaketime,
  zstd,
}:
# Build the persistent /nix filesystem shared by ARM board disk images.
let
  closureInfo = pkgs.buildPackages.closureInfo { rootPaths = storePaths; };
in
pkgs.stdenv.mkDerivation {
  name = "nix-btrfs-fs.img${lib.optionalString compressImage ".zst"}";

  nativeBuildInputs = [
    btrfs-progs
    libfaketime
    pkgs.buildPackages.util-linux
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
    # Recent btrfs-progs obtains ownership through statx, which fakeroot does
    # not intercept.  Present the build user's uid as uid 0 in a user namespace
    # so mkfs records root ownership for the complete Nix store.
    faketime -f "1970-01-01 00:00:01" \
      unshare --user --map-root-user -- \
      mkfs.btrfs -L ${volumeLabel} -U ${uuid} -r rootImage --shrink "$img"
    btrfs check "$img"

    ${lib.optionalString compressImage ''
      zstd -v --no-progress "$img" -o "$out"
    ''}
  '';
}
