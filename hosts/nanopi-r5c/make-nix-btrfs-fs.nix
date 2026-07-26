{
  pkgs,
  lib,
  storePaths,
  compressImage ? false,
  populateImageCommands ? "",
  volumeLabel,
  uuid ? "44444444-4444-4444-8888-888888888888",
  btrfs-progs,
  libfaketime,
  fakeroot,
  zstd,
}:
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
    faketime -f "1970-01-01 00:00:01" \
      fakeroot mkfs.btrfs -L ${volumeLabel} -U ${uuid} -r rootImage --shrink "$img"
    btrfs check "$img"

    ${lib.optionalString compressImage ''
      zstd -v --no-progress "$img" -o "$out"
    ''}
  '';
}
