# napalm 学习笔记

## 1. 是什么

`napalm` 用 Nix 构建 npm 包：解析 `package-lock.json`，把依赖全部
fetch 进 Nix store，再起一个本地 npm registry 喂给 `npm install`。
MIT 协议，作者 nmattia，117 star，项目正在找新维护者。

## 2. 用法

```nix
napalm.buildPackage ./. {
  # 可选：packageLock / additionalPackageLocks
  # nodejs、preNpmHook/postNpmHook、patchPackages、
  # customPatchPackages、installPhase
}
```

`patchPackages = true` 时会把依赖重新打包，修复 shebang 和
integrity hash，避免 `Invalid interpreter` 一类问题；
`customPatchPackages` 可按 `"包名"."版本"` 精确覆盖。

## 3. 工作流程

1. 读取所有 lockfile 并解析；
2. 把每个包 fetch 到 Nix store；
3. 可选：patch 包并更新 lockfile 的 integrity；
4. 生成 snapshot（包名/版本 → store 内 tarball 路径）；
5. 启动 `napalm-registry` 模拟 npm registry；
6. 配置 npm 使用本地 registry；
7. override npm 注入 hooks；
8. 执行 npm 命令并安装。

## 4. napalm-registry

- Haskell Servant/Warp 服务，从 snapshot JSON 提供包 metadata 和
  tarball；
- 支持 scoped/unscoped 包、版本查询和 tarball 下载；
- `--report-to` 可让 warp 选随机端口并写文件，方便构建期协调。

## 5. CI

- CircleCI（旧式）：安装 Nix 后跑 `./script/test`，构建
  hello-world / deps / workspace / bitwarden-cli 等测试包。

## 6. 与我们仓库的启发

- 我们 [language-packaging.md](./language-packaging.md) 已决定 npm
  走 nixpkgs 原生 `fetchNpmDeps` / `buildNpmPackage`；
- napalm 的“本地 registry 模拟”思路很有意思，但在 npm 生态
  更新后维护成本高，和 npmlock2nix 一样只作历史参考。

## 7. 参考

- [napalm](https://github.com/nix-community/napalm)
- [npmlock2nix 学习笔记](./npmlock2nix.md)
