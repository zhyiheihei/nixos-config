# gomod2nix 学习笔记

## 1. 是什么

`gomod2nix` 把基于 Go modules 的应用转换成 Nix 表达式：Go 写的 CLI 生成
`gomod2nix.toml`，Nix 侧提供 `buildGoApplication` / `mkGoEnv` 等 builder
函数。项目源自 Tweag 的 Trustix 工作（NLNet/NGI 资助），维护者为
`@marcusramberg`，MIT 协议，当前 308 star / 80 fork。

## 2. 核心工作流

在 Go 项目目录运行 `gomod2nix`（或 `gomod2nix generate`）：

1. 解析 `go.mod` / `go.sum`，执行 `go mod download --json`；
2. 对每个依赖目录用 NAR 计算 sha256；
3. 写出 `gomod2nix.toml`（schema 3），每个依赖带 `version` 和 `hash`。

Nix 侧通过 overlay 引入 builder：

```nix
pkgs.buildGoApplication {
  pname = "myapp";
  version = "0.1";
  src = ./.;
  modules = ./gomod2nix.toml;
}
```

可选能力：

- `generate --with-deps`：额外生成 `cachePackages`，构建时预热 GOCACHE；
- `import`：把依赖源码直接导入 Nix store，开发环境免重复下载；
- 直接传 import path 参数：临时生成项目并写 `tools.go`，可打包某个仓库
  的特定子包。

## 3. 为什么不能直接引用 go.sum（设计动机）

Tweag 2021 年的发布博客解释了原因：

- `go.sum` 是扁平校验列表而不是依赖图，无法像 poetry2nix 那样按依赖
  增量构建；
- Go 自己的目录 hash 与 Nix NAR hash 不兼容；
- import path 到仓库的解析（`RepoRootForImport`）需要网络探测，Nix
  求值环境里无法做；
- 因此它采用“代码生成 + 每个依赖固定 NAR hash”的路线。

与当时其他方案对比：

- `vgo2nix`：模拟旧 GOPATH 构建，同一仓库多个版本时会出错；
- `buildGoModule`：单一 fixed-output derivation + `vendorSha256`，
  依赖不可共享、hash 粒度粗、失效后要重新下载；
- `gomod2nix`：每个依赖单独 fetch（可跨包共享），构建时用符号链接
  组装 vendor 树，而不是复制源码。

## 4. Nix 侧实现

`builder/default.nix` 主要包含：

- `parser.nix`：纯 Nix 解析 `go.mod`；
- `fetchGoModule` + `fetch.sh`：`go mod download` 后拷贝目录，用
  recursive `outputHash`；
- `mkVendorEnv`：用 Go 小工具 `symlink` 把各依赖源码符号链接成
  vendor 树，处理 replace 和嵌套路径；
- `mkGoCacheEnv`：把预编译的 GOCACHE 打成 `cache.tar.zst`，后续构建
  解压复用；
- `selectGo`：按 `go.mod` 要求的 Go 版本从 nixpkgs 选兼容属性；
- hooks：`goConfigHook`（vendor/缓存恢复、`-mod=vendor`、trimpath）、
  `goBuildHook`、`goCheckHook`、`goInstallHook`。

`mkGoEnv` 提供开发 shell，能读 `tools.go` 自动 `go install` 工具依赖。
flake 支持 aarch64/x86_64 的 Linux/macOS 以及 riscv64-linux。

## 5. CI 与测试

- `ci.yml`：treefmt、golangci-lint、重新生成 `gomod2nix.toml` 后跑
  `git diff --exit-code`（防锁文件漂移）、用 `tests/run.go list`
  动态生成构建测试矩阵；
- 测试样例来自 nixpkgs 里的真实 Go 项目：helm、minikube、ethermint、
  cli-args、cross、vendored-modules 等；GitHub Actions 上跳过最重的
  helm/minikube/cross；
- master 分支最近一次 CI 运行（2026-02-08）为 success。

## 6. 对我们仓库的启发

- 我们现有的 Go 包（`dnscontrol`、`sun-panel`、`docker-proxy`、
  `vertex`）走 nixpkgs `buildGoModule` + `vendorHash`，包数量少，不需要迁移；
- gomod2nix 的价值在“多个 Go 包共享依赖、依赖 hash 频繁变化”的场景；
  如果以后 zhyi-packages 的 Go 包变多，值得重新评估；
- 它的“重新生成 + diff 检查”CI 防漂移模式和 GOCACHE 预热思路可以借鉴。

## 7. 参考

- [gomod2nix](https://github.com/nix-community/gomod2nix)
- [Announcing Gomod2nix (Tweag)](https://www.tweag.io/blog/2021-03-04-gomod2nix/)
- [Getting started](https://github.com/nix-community/gomod2nix/blob/master/docs/getting-started.md)
- [Nix API reference](https://github.com/nix-community/gomod2nix/blob/master/docs/nix-reference.md)
