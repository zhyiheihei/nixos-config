{
  lib,
  fetchurl,
  buildPythonPackage,
  numpy,
  psutil,
  ruamel-yaml,
}:

# Rockchip NPU inference runtime (lite variant), used by
# immich-machine-learning's RKNN backend (MACHINE_LEARNING_RKNN).
#
# Only aarch64-linux manylinux wheels are published on PyPI (no sdist, no
# x86_64); the wheel bundles prebuilt .so, so it must be fetched as-is and
# installed with format = "wheel".
buildPythonPackage rec {
  pname = "rknn-toolkit-lite2";
  version = "2.3.2";

  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/ff/db/64c756f3f06b219e92ff4f0fd4e000870ee49f214d505ff01c8b0275e26d/rknn_toolkit_lite2-2.3.2-cp312-cp312-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
    sha256 = "e1e4ec691fed900c0e6fde5e7d8eeba17f806aa45092b63b361ee775e2c1b50e";
  };

  dependencies = [
    numpy
    psutil
    ruamel-yaml
  ];

  # The wheel is cp312-tagged; fail fast on other interpreters instead of
  # silently importing the wrong ABI.
  pythonImportsCheck = [ "rknn" ];

  meta = {
    description = "RKNN-Toolkit-Lite2: Rockchip NPU inference runtime (lite)";
    homepage = "https://github.com/airockchip/rknn-toolkit2";
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "aarch64-linux" ];
  };
}
