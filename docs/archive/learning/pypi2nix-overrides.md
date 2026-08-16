# pypi2nix-overrides 学习笔记

## 1. 是什么

`pypi2nix-overrides` 是 seppeljordan 维护的 [pypi2nix](https://github.com/nix-community/pypi2nix)
（已学）**默认 overrides 集**：pypi2nix 无法自动检测全部构建/运行
依赖，这里集中提供“经过测试的已知补丁”。BSD-3-Clause，1 star，
Nix，2026-06 仍在维护；pypi2nix 默认就会包含它。

## 2. overrides.nix

`{ pkgs, python }` → `self: super:`，对包做 `overrideDerivation`：

- 给 `setuptools-scm` 依赖的包（apipkg、execnet、py、
  pytest-django、pytest-black 等）补 buildInputs；
- `mccabe` 补 pytest-runner、`zipp` 补 toml；
- `setuptools` / `pip` / `wheel` 设
  `pipInstallFlags = [ "--ignore-installed" ]`。

只对 `super` 里真实存在的包生效（`filterAttrs`）。

## 3. 测试

- 内置包集：flake8、pytest、django、pypi2nix、packaging；
- `build_packages.py`：为每个包集生成 `requirements.nix` 并
  `nix build`，验证 overrides 有效；CI 用 Travis（老配置）。

## 4. 对我们仓库的启发

- 我们不用 pypi2nix，不引入；
- 它体现“生成器检测不到的依赖用集中 overrides 补”的模式，和
  nixpkgs pythonPackages 的 `packageOverrides`、poetry2nix
  overrides 同构；
- 若要给 zhyi-packages 的 Python 生成器做“已知修补表”，可照此
  组织并配一组真实包集回归测试。

## 5. 参考

- [pypi2nix-overrides](https://github.com/nix-community/pypi2nix-overrides)
