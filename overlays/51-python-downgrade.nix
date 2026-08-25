# Python 3.14 移除了自带 setuptools，xstatic 系列包的 setup.py 仍用
# pkg_resources.declare_namespace 声明命名空间，构建时缺 setuptools 导致
# ModuleNotFoundError: No module named 'pkg_resources'。
# 用 python3.packageOverrides 给 xstatic-* 包注入 setuptools 到 nativeBuildInputs。
{ lib, ... }:
_final: prev:
let
  addSetuptools = super: name: pkg: pkg.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
  });
in
{
  python3 = prev.python3.override (
    lib.fix (self: {
      self = self;
      packageOverrides = _pyfinal: pysuper: {
        xstatic = addSetuptools pysuper "xstatic" pysuper.xstatic;
        xstatic-asciinema-player = addSetuptools pysuper "xstatic-asciinema-player" pysuper.xstatic-asciinema-player;
        xstatic-bootbox = addSetuptools pysuper "xstatic-bootbox" pysuper.xstatic-bootbox;
        xstatic-bootstrap = addSetuptools pysuper "xstatic-bootstrap" pysuper.xstatic-bootstrap;
        xstatic-font-awesome = addSetuptools pysuper "xstatic-font-awesome" pysuper.xstatic-font-awesome;
        xstatic-jquery = addSetuptools pysuper "xstatic-jquery" pysuper.xstatic-jquery;
        xstatic-jquery-file-upload = addSetuptools pysuper "xstatic-jquery-file-upload" pysuper.xstatic-jquery-file-upload;
        xstatic-jquery-ui = addSetuptools pysuper "xstatic-jquery-ui" pysuper.xstatic-jquery-ui;
        xstatic-pygments = addSetuptools pysuper "xstatic-pygments" pysuper.xstatic-pygments;
      };
    })
  );
}
