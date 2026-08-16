# pip2nix 学习笔记

## 1. 是什么

`pip2nix` 根据 pip requirements 生成 Python 包的 Nix 表达式，复用 pip
自己的解析器和依赖解析逻辑。GPLv3+，2015 年由 Tomasz Kontusz 创建，
后由 Johannes Bornhold、Asko Soukka 接手并移入 nix-community。

项目状态偏旧：flake 仍 pin 到 nixos-20.09，README 自称
"not yet mature"，changelog 停在 0.8.0，版本号停留在 0.9.0.dev1。

## 2. 用法

```bash
pip2nix generate -r requirements.txt
pip2nix scaffold --package myProject
```

支持 pip 兼容的 `-r` / `-c` / `-e` / index-url / no-binary 等参数；
也可以用 `pip2nix.ini` 固定调用方式。flake 用户可
`nix run github:nix-community/pip2nix -- generate -r requirements.txt`。

## 3. 实现方式

- 核心是子类化 pip 内部的 `InstallCommand`（`NixFreezeCommand`），
  复用 pip resolver 收集 requirements、setup_requires、tests_require，
  但只下载、不安装；
- 对每个包调 `nix-prefetch-url` / `nix-prefetch-git` /
  `nix-prefetch-hg` 计算 sha256，渲染成 nixpkgs `buildPythonPackage`
  的 override 表达式（`self: super: { ... }`），可随 fixed point
  扩展 nixpkgs Python 包集合；
- 与 pypi2nix 的区别：pip2nix 复用 nixpkgs 包函数，pypi2nix 维护
  独立包树；
- 支持 PyPI、本地路径、git、hg、wheel；license 从 PKG-INFO/METADATA
  映射到 `nixpkgs.lib.licenses`；
- 生成的 `nativeBuildInputs` 会有重复依赖（上游自身输出也存在），
  产物不算干净。

## 4. CI 与工程

- `build.yml`：nixpkgs 18.09-20.09 × python 2.7-3.9 矩阵构建；
  bootstrap job 重新生成表达式并 `git diff`；docs job 构建文档；
- 测试用 pytest，涉及真正调用 nix prefetch 的 HTTP 用例标 xfail；
- 项目基本停滞，只能作为历史参考。

## 5. 对我们仓库的启发

- zhyi-packages 的 Python 包走 nixpkgs 原生 `buildPythonPackage` +
  maturin，符合我们文档里的结论，不需要引入 pip2nix；
- 可借鉴的是“复用语言生态自己的解析器做代码生成”和“以 fixed point
  扩展 nixpkgs 包集”的思路；新项目不应选这种长期不维护的工具。

## 6. 参考

- [pip2nix](https://github.com/nix-community/pip2nix)
- [pypi2nix](https://github.com/nix-community/pypi2nix)
- [pip2nix docs](https://pip2nix.readthedocs.io/)
