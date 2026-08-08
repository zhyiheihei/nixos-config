# pypi2nix 学习笔记

## 1. 是什么

`pypi2nix` 是根据 `requirements.txt` 生成 Python 包 Nix 表达式的
工具，曾是 pip2nix 的主要对手，并一度进入 nixpkgs。仓库已归档，
最后一次活跃约在 2021 年，版本 2.0.4。

## 2. 用法与产物

```bash
pypi2nix -e packageA -e packageB==0.1 -r requirements.txt
```

生成三个文件：

- `requirements_frozen.txt`：等价 `pip freeze` 的完整锁定版本；
- `requirements.nix`：生成的 Python 包集合（含 `mkDerivation` 和
  `interpreter`）；
- `requirements_override.nix`：给用户留的覆盖入口。

生成的包集合可这样用：

```nix
python = import ./requirements.nix { inherit pkgs; };
python.packages."coverage"
```

## 3. 实现与测试

- 与 pip2nix 的关键区别：pypi2nix 维护自己的 Python 包树，不直接
  复用 nixpkgs 的 `python3Packages`；
- 依赖 `nix-prefetch-git` / `nix-prefetch-hg` 计算源码 hash，模板
  用 Jinja2，requirements 解析用 parsley；
- 有大量集成测试，直接对真实包生成并构建（aiohttp、scipy、flake8、
  pynacl、tornado 等），还有 `install_test.py` 做安装验证；
- CI 是 Travis，覆盖 nixos-19.09 / 20.03 / unstable 多个 channel。

## 4. 与我们的关系

- 我们在 `pip2nix` 笔记里已把 pip2nix/pypi2nix 归为历史参考；
  zhyi-packages 的 Python 包继续走 nixpkgs 原生
  `buildPythonPackage` + maturin，不需要迁移；
- 它的集成测试思路（拿真实包跑完整生成 + 构建）仍值得借鉴。

## 5. 参考

- [pypi2nix](https://github.com/nix-community/pypi2nix)
- [pip2nix 学习笔记](./pip2nix.md)
