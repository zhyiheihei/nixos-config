# govendor 学习笔记

## 1. 是什么

`nix-community/govendor`（org 维护者 c00w，MIT，2 star，Go，2020-08
已归档）托管的是 **Vend** 工具（module 名
`github.com/nomad-software/vend`）：把 Go module 的**完整依赖树**
拷进 `vendor/`。归档原因是 Nix 侧后来改用 `vendorHash` /
`vendorHashSha256`，不再需要这个外部工具。

## 2. 为什么需要它

`go mod vendor` 会“挑文件”拷进 vendor，导致：

- Cgo 项目丢包目录外的 C 文件（golang/go#26366）；
- 依赖的测试和 examples 被忽略。

Vend 像普通包管理器一样整包复制，保证离线可构建、可跑依赖测试。

## 3. 用法与实现

```sh
cd $GOPATH/mypackage
vend            # 完整 vendoring
vend -pkg       # 只拷 import 的包
```

- 依赖 `go mod download -json` 和 `go list -m -json` 拿模块清单；
- `cli.UpdateModule()` 先跑 `go mod download`，然后解析 JSON 逐个
  模块复制；
- 不支持 replace directive（README 明说没有共识）。

## 4. 对我们仓库的启发

- 我们不打 Go 包，且现代 nixpkgs 用 `vendorHash`，不需要引入；
- 它是 Nix + Go 打包历史中的一环：从“外部工具整树 vendor”进化到
  “Nix 自己管理 vendor 目录 hash”；
- 理解它有助于看懂旧 nixpkgs buildGoPackage 配置。

## 5. 参考

- [govendor](https://github.com/nix-community/govendor)
