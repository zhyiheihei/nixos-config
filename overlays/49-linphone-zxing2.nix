_: final: prev: {
  # linphone-sdk 5.4.x still includes ZXing/BitMatrix.h, which zxing-cpp 3.x
  # removed; keep zxing-cpp on 2.3.0 until linphone catches up.
  zxing-cpp = prev.zxing-cpp.overrideAttrs (old: {
    version = "2.3.0";
    src = prev.fetchFromGitHub {
      owner = "zxing-cpp";
      repo = "zxing-cpp";
      tag = "v2.3.0";
      hash = "sha256-e3nSxjg8p+1DEUbZOh4C2zfnA6iGhNJMPiIe2oJEbRo=";
    };
  });
}
