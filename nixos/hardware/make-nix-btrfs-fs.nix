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
  fakeroot,
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
    # Keep ownership correction and mkfs in one fakeroot session so the image
    # never records the sandbox builder's uid/gid.
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
