{ inputs, ... }:
final: prev: {
  # Rockchip NPU (rknpu) acceleration for Immich machine-learning, following
  # the official RKNN backend docs (rknpu driver >= 0.9.8 + -rknn deps):
  #   https://immich.app/docs/features/ml-hardware-acceleration
  # opi5p runs the Armbian vendor kernel (6.1.115-armbian) which ships the
  # rknpu driver; this overlay only supplies the Python-side deps.
  #
  # rknn-toolkit-lite2 publishes aarch64 wheels for cp37..cp312 only, so the
  # machine-learning app must run on python312 (nixpkgs default python3 is 3.14).
  python312 = prev.python312.override {
    self = prev.python312;
    packageOverrides = pyfinal: pyprev: {
      rknn-toolkit-lite2 = pyprev.callPackage ../pkgs/rknn-toolkit-lite2 { };

      # Enhance immich-machine-learning inside the python312 package set:
      # the top-level `override { python3 = ... }` below will then pick up
      # this enhanced variant, keeping the `.override` chain intact for the
      # immich NixOS module (which calls immich-machine-learning.override { ... }).
      immich-machine-learning = pyprev.immich-machine-learning.overridePythonAttrs (old: {
        dependencies =
          (old.dependencies or [ ])
          ++ [
            pyfinal.rknn-toolkit-lite2
            pyfinal.onnxruntime
          ];
      });
    };
  };

  # immich-machine-learning takes `python3` as its interpreter argument.
  # Point it at python312 (whose package set carries rknn-toolkit-lite2).
  immich-machine-learning = prev.immich-machine-learning.override {
    python3 = final.python312;
  };
}
