# Python 3.14 移除了自带 setuptools，xstatic 系列包的 setup.py 仍用
# pkg_resources.declare_namespace 声明命名空间，构建时缺 setuptools 导致
# ModuleNotFoundError: No module named 'pkg_resources'。
# 用 packageOverrides 给所有 xstatic-* 包注入 setuptools 到 nativeBuildInputs。
_: final: prev:
{
  python3 = prev.python3.override {
    self = final.python3;
    packageOverrides = _self: super: {
      xstatic = super.xstatic.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-asciinema-player = super.xstatic-asciinema-player.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-bootbox = super.xstatic-bootbox.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-bootstrap = super.xstatic-bootstrap.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-font-awesome = super.xstatic-font-awesome.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-jquery = super.xstatic-jquery.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-jquery-file-upload = super.xstatic-jquery-file-upload.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-jquery-ui = super.xstatic-jquery-ui.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
      xstatic-pygments = super.xstatic-pygments.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      });
    };
  };
}
