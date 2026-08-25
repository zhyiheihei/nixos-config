# Python 3.14 移除了自带 setuptools，xstatic 系列包的 setup.py 仍用
# pkg_resources.declare_namespace 声明命名空间，构建时缺 setuptools 导致
# ModuleNotFoundError: No module named 'pkg_resources'。
# 用 packageOverrides 给所有 xstatic-* 包注入 setuptools 到 nativeBuildInputs。
_: final: prev:
{
  python3 = prev.python3.override (
    self: super: {
      pkgs = super.pkgs.overrideScope (
        _final: ssuper: builtins.mapAttrs
          (name: pkg: pkg.overridePythonAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ ssuper.setuptools ];
          }))
          {
            xstatic = ssuper.xstatic;
            xstatic-asciinema-player = ssuper.xstatic-asciinema-player;
            xstatic-bootbox = ssuper.xstatic-bootbox;
            xstatic-bootstrap = ssuper.xstatic-bootstrap;
            xstatic-font-awesome = ssuper.xstatic-font-awesome;
            xstatic-jquery = ssuper.xstatic-jquery;
            xstatic-jquery-file-upload = ssuper.xstatic-jquery-file-upload;
            xstatic-jquery-ui = ssuper.xstatic-jquery-ui;
            xstatic-pygments = ssuper.xstatic-pygments;
          }
      );
    }
  );
}
