# setup.nix 学习笔记

## 1. 是什么

`setup.nix` 是 datakurre 为 Python 开发者准备的 Nix 工具集：以
`setup.cfg` + `requirements.txt` + pip2nix 生成 `requirements.nix`
为工作流，提供开发、测试、打包 Python 包的声明式 targets。64 star，
已归档；README 标明弃用方向是“minimal Python toolchain scaffold
for pip2nix”。

目标场景是 Nixpkgs 与普通 Python 包开发混存的工程：Nixpkgs 里已有
的包直接复用，缺版本或缺包的才从 pip2nix requirements 补齐。

## 2. 核心模型

`default.nix` 是一个带大量参数的函数：

```nix
setup {
  inherit pkgs pythonPackages;
  src = ./.;
  doCheck = true;
  image_entrypoint = "/bin/hello-world";
}
```

主要参数：`src`（项目目录）、`requirements`（requirements.nix 路径，
默认 `./requirements.nix`）、`overrides`（包修补函数）、
`defaultOverrides`、`buildInputs` / `propagatedBuildInputs`、
`doCheck`，以及一整套 `image_*` Docker 镜像参数。

## 3. setup.cfg 解析

用 `runCommand` + Python `configparser` 把 `setup.cfg` 转成 JSON
（ASCII 编码，多行值拆成列表），再 `builtins.fromJSON` 读入 Nix。
这样 `install_requires`、`setup_requires`、`tests_require`、
`entry_points` 都能声明式进入构建。

## 4. Nixpkgs 与 pip2nix 合并

`requirementsFunc` 接收 `pkgs/fetchurl/fetchgit/fetchhg`，返回
每个包名对应的 derivation。然后通过
`pythonPackages.python.override { packageOverrides = self: super: ... }`
做三件事：

1. Nixpkgs 已存在的包：用 `overridePythonAttrs` 把 pip2nix 的
   src/version 与依赖合并进 Nixpkgs 原 derivation，`doCheck = false`；
2. Nixpkgs 没有的包：直接用 pip2nix 的 derivation；
3. 最后叠加用户 `overrides` 和内置 `defaultOverrides`。

合并函数还生成 `-` → `_` 的规范化名字，兼容两种包名写法。

## 5. 输出 targets

- 有 `setup.cfg` 时是“包模式”：`build` / `install` / `develop` /
  `shell` / `sdist` / `bdist_wheel` / `bdist_docker` / `tests`；
- 没有时是“环境模式”：把 requirements 全部装进
  `python.withPackages` 的 `env`，适合只做开发环境；
- `tests` 走 NixOS 功能测试 `make-test`，读取项目 `tests.nix`；
- Docker 镜像不依赖本机 Docker daemon，直接由
  `dockerTools.buildImage` 构建，再 `docker load < result`。

## 6. CI 与维护状态

CI 是 Travis（`language: nix`），跑
`examples/package` 和 `examples/env` 的 make 目标
（nix-env/nix-build/nix-test/nix-acceptance-test/nix-sdist/nix-wheel）。
仓库 2020 年停止更新，NixOS 19.03 时代产物；新项目应直接看
pip2nix、poetry2nix 或 nixpkgs python 工具链。

## 7. 对我们仓库的启发

- “Nixpkgs 优先、pip2nix 补齐”的合并策略正是后来
  nixpkgs `packageOverrides` 常见做法，也解释了为什么 poetry2nix
  会有 `preferWheels` 等选项；
- `setup.cfg` 用 Python 解析成 JSON 再 fromJSON，比逐字段 Nix
  正则解析更稳，是“用结构化解析器处理结构化配置”的范例；
- 我们不直接引入：仓库已归档，且我们只用 nixpkgs/poetry2nix
  打包 Python 依赖。

## 8. 参考

- [setup.nix](https://github.com/nix-community/setup.nix)
- [pip2nix](https://github.com/nix-community/pip2nix)
