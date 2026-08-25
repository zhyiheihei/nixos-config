# Python 3.14 的 setuptools 83 移除了 pkg_resources，而 xstatic 系列包的
# setup.py / __init__.py 仍用 pkg_resources.declare_namespace 声明命名空间。
# 用 setuptools_80（仍含 pkg_resources）作为 build-system 替代 setuptools。
# 这是 nixpkgs master 已有的修复，我们的 nixpkgs 版本尚未包含。
#
# 必须通过 pythonPackagesExtensions 注入而非 python3Packages.overrideScope，
# 因为 bepasty 包内部用 python3.override { packageOverrides = ... } 创建了
# 独立 scope，packageOverrides 会被完全替换，但 pythonPackagesExtensions
# 会传递到所有派生 scope。
_: final: prev:
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyfinal: pysuper: {
      xstatic = pysuper.xstatic.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-asciinema-player = pysuper.xstatic-asciinema-player.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-bootbox = pysuper.xstatic-bootbox.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-bootstrap = pysuper.xstatic-bootstrap.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-font-awesome = pysuper.xstatic-font-awesome.overridePythonAttrs (_old: {
        pyproject = true;
        format = null;
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-jquery = pysuper.xstatic-jquery.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-jquery-file-upload = pysuper.xstatic-jquery-file-upload.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-jquery-ui = pysuper.xstatic-jquery-ui.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
      xstatic-pygments = pysuper.xstatic-pygments.overridePythonAttrs (_old: {
        build-system = [ pysuper.setuptools_80 ];
      });
    })
  ];
}
