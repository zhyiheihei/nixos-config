# Python 3.14 移除了自带 setuptools，xstatic 系列包的 setup.py 仍用
# pkg_resources.declare_namespace 声明命名空间，构建时缺 setuptools 导致
# ModuleNotFoundError: No module named 'pkg_resources'。
# 给所有 xstatic-* 包注入 setuptools 到 nativeBuildInputs。
_: final: prev:
{
  python3 =
    let
      self = prev.python3.override { inherit self; };
    in
    self.override (
      _: super: {
        pkgs = super.pkgs.overrideScope (
          _: ssuper: {
            xstatic = ssuper.xstatic.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-asciinema-player = ssuper.xstatic-asciinema-player.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-bootbox = ssuper.xstatic-bootbox.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-bootstrap = ssuper.xstatic-bootstrap.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-font-awesome = ssuper.xstatic-font-awesome.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-jquery = ssuper.xstatic-jquery.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-jquery-file-upload = ssuper.xstatic-jquery-file-upload.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-jquery-ui = ssuper.xstatic-jquery-ui.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
            xstatic-pygments = ssuper.xstatic-pygments.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
            });
          }
        );
      }
    );
}
