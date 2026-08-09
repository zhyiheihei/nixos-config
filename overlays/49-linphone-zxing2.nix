_: final: prev:
let
  # linphone-sdk 5.4.x still includes ZXing/BitMatrix.h, which zxing-cpp 3.x
  # removed.  Only linphone needs the 2.x API, so keep the rest of the package
  # set on the nixpkgs zxing-cpp version.
  zxing-cpp-2 = prev.zxing-cpp.overrideAttrs (old: {
    version = "2.3.0";
    src = prev.fetchFromGitHub {
      owner = "zxing-cpp";
      repo = "zxing-cpp";
      tag = "v2.3.0";
      hash = "sha256-e3nSxjg8p+1DEUbZOh4C2zfnA6iGhNJMPiIe2oJEbRo=";
    };
  });
  linphonePackages = prev.linphonePackages // {
    liblinphone = prev.linphonePackages.liblinphone.override {
      zxing-cpp = zxing-cpp-2;
    };
  };
in
{
  zxing-cpp-2 = zxing-cpp-2;
  linphonePackages = linphonePackages // {
    linphone-desktop = prev.linphonePackages.linphone-desktop.override {
      liblinphone = linphonePackages.liblinphone;
    };
  };
}
