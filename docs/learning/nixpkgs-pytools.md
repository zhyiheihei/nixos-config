# nixpkgs-pytools 学习笔记

## 1. 是什么

`nixpkgs-pytools` 是 costrouc 写的 Python 工具集：目标是消除手写
nixpkgs derivation 的繁琐工作。49 star，MIT，PyPI 上发布过
1.3.0（`pip install nixpkgs-pytools`）。2019 年后基本停更，2025-03
还有零星提交。

两个命令：

- `python-package-init`：从 PyPI 元数据生成近乎完整的
  `buildPythonPackage` derivation；
- `python-rewrite-imports`：用 rope 批量改写源码里的 import。

## 2. python-package-init

```bash
python-package-init nixpkgs-pytools --nixpkgs-root=<path to nixpkgs>
```

流程：

1. 请求 PyPI JSON API，拿 `info` 和 `releases`；
2. 选择 sdist（否则报错），取 sha256、url、扩展名；
3. 归一化 pname、映射 license 到 nixpkgs、解析依赖
   （build/check/propagated）和“可能需要的 extra inputs”；
4. 检测 `pytest`/`nose` 自动生成 `checkPhase`；
5. 用 Jinja 模板渲染 `default.nix`：

```nix
{ lib, buildPythonPackage, fetchPypi, ... }:
buildPythonPackage rec {
  pname = "...";
  version = "...";
  src = fetchPypi { inherit pname version; sha256 = "..."; };
  checkInputs = [ pytest ];
  checkPhase = "pytest";
  meta = { ... };
}
```

输出默认写当前目录 `default.nix`，`--stdout` 可打印；
`--nixpkgs-root` 模式还会把 `<name> = callPackages ... {};` 追加进
`pkgs/top-level/python-modules.nix`。模板刻意“过度完整”，留下
占位注释（license 映射失败、条件依赖、extra inputs）让用户决定。

## 3. python-rewrite-imports

用 [rope](https://github.com/python-rope/rope) 的 Rename refactoring
重写整棵树里的模块导入。示例场景：旧版 airflow 需要把
`flask_appbuilder` / `pendulum` 换成固定版本 vendor 包时，批量替换
import：

```bash
python-rewrite-imports --path /tmp/airflow-master \
  --replace flask_appbuilder flask_appbuilder_1_13_...
```

实现里用一个临时目录放旧模块名的 `__init__.py`，让 rope 能
`find_module`，再执行重命名 changes。

## 4. 工程与 CI

- `setup.py`：entry_points 挂两个命令，依赖 jinja2/setuptools/rope；
- `shell.nix`：`buildPythonPackage` 开发环境（pytest、black）；
- CI 是 Travis：`pytest` 跑 `tests/`，打 tag 时发布 PyPI；
- 无 GitHub Actions、无 flake。

## 5. 对我们仓库的启发

- 我们不用它，Python 打包走 nixpkgs/poetry2nix 即可；
- 它的“生成 90% + 注释指出剩余 10%”思路，比追求全自动生成的
  工具更务实，写包生成器时可以借鉴；
- `--nixpkgs-root` 直接把生成结果落进 nixpkgs 树并更新
  python-modules.nix 的做法，类似我们给 zhyi-packages 加包时
  的“模板 + 注册表”两步，只是 nixpkgs 侧要更谨慎。

## 6. 参考

- [nixpkgs-pytools](https://github.com/nix-community/nixpkgs-pytools)
