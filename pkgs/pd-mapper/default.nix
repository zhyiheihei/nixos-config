{
  stdenv,
  lib,
  fetchFromGitHub,
  pkg-config,
  qrtr,
}:

stdenv.mkDerivation {
  pname = "pd-mapper";
  version = "unstable-2024";

  src = fetchFromGitHub {
    owner = "andersson";
    repo = "pd-mapper";
    rev = "5ecd2fe926aca7abfe40724177f63b942cff3947";
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ qrtr ];

  installFlags = [ "prefix=$(out)" ];

  meta = with lib; {
    description = "Qualcomm Protection Domain mapper";
    homepage = "https://github.com/andersson/pd-mapper";
    license = licenses.bsd3;
    platforms = platforms.aarch64;
  };
}