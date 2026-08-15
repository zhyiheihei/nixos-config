{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  python3Packages,
}:
buildHomeAssistantComponent rec {
  owner = "Tasshack";
  domain = "dreame_vacuum";
  version = "v2.0.0b23";

  src = fetchFromGitHub {
    owner = "Tasshack";
    repo = "dreame-vacuum";
    rev = "v2.0.0b23";
    hash = "sha256-G8LfchX9cLvTlaVOgCly7UheG6pZYiU8JAcG1GwFwAA=";
  };

  # Upstream ships CRLF line endings; normalize the files we touch. The map
  # optimizer wants py-mini-racer (a V8 JS wrapper), which is not packaged in
  # nixpkgs: make the import optional so DreameVacuumMapDecoder.optimize() falls
  # back to its pure-python path, and drop the requirement from the manifest so
  # the nixpkgs manifest-requirements check passes.
  prePatch = ''
    sed -i 's/\r$//' \
      custom_components/dreame_vacuum/dreame/map.py \
      custom_components/dreame_vacuum/manifest.json

    sed -i 's/^from py_mini_racer import MiniRacer$/try:\n    from py_mini_racer import MiniRacer\nexcept ImportError:\n    MiniRacer = None/' \
      custom_components/dreame_vacuum/dreame/map.py

    sed -i 's/^                if js_optimizer:$/                if js_optimizer and MiniRacer is not None:/' \
      custom_components/dreame_vacuum/dreame/map.py

    sed -i '/"mini-racer",/d' \
      custom_components/dreame_vacuum/manifest.json
  '';

  dependencies = with python3Packages; [
    pillow
    numpy
    requests
    pycryptodome
    python-miio
    paho-mqtt
  ];

  meta = {
    homepage = "https://github.com/Tasshack/dreame-vacuum";
    description = "Home Assistant integration for Dreame robot vacuums with map support";
    license = lib.licenses.mit;
  };
}
