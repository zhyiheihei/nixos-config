# Python 3.14 移除了自带 setuptools，xstatic 系列包的 setup.py 仍用
# pkg_resources.declare_namespace 声明命名空间，构建时缺 setuptools 导致
# ModuleNotFoundError: No module named 'pkg_resources'。
# 直接在 python3Packages scope 上 overrideScope 注入 setuptools。
_: final: prev:
{
  python3Packages = prev.python3Packages.overrideScope (
    _final: super: builtins.mapAttrs
      (name: pkg: pkg.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
      }))
      {
        xstatic = super.xstatic;
        xstatic-asciinema-player = super.xstatic-asciinema-player;
        xstatic-bootbox = super.xstatic-bootbox;
        xstatic-bootstrap = super.xstatic-bootstrap;
        xstatic-font-awesome = super.xstatic-font-awesome;
        xstatic-jquery = super.xstatic-jquery;
        xstatic-jquery-file-upload = super.xstatic-jquery-file-upload;
        xstatic-jquery-ui = super.xstatic-jquery-ui;
        xstatic-pygments = super.xstatic-pygments;
      }
  );
}
