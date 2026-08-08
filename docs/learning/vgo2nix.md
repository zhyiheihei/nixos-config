# vgo2nix 学习笔记

## 1. 是什么

`vgo2nix` 是早期 Go 工具：把 `go.mod` 转成 nixpkgs
`buildGoPackage` 兼容的 `deps.nix`。MIT 协议，89 star，已弃用，
README 明确推荐 [gomod2nix](./gomod2nix.md) 作为替代。

## 2. 实现

- `go list -mod mod -json -m all` 列出所有 module；
- 用 `vcs.RepoRootForImportPath` 解析仓库，处理 replace、submodule
  `moduleDir` 和版本 → git ref（tag 或 pseudo-version 的 commit）；
- 并行跑 `nix-prefetch-git` 计算 sha256，已有 hash 直接复用；
- 输出 `deps.nix`：每个包
  `{ goPackagePath; fetch = { type = "git"; url; rev; sha256; moduleDir; }; }`。

## 3. 测试与 CI

- 测试目录里放项目文件 + `expected.nix`，跑 `vgo2nix --dir` 后
  `filecmp` 对比输出；
- GitHub Actions `test.yml` 只跑 `make test`。

## 4. 与 gomod2nix 的关系

- vgo2nix 模拟 GOPATH 构建，多个版本同仓库时会出错（Tweag 博客
  指出）；
- gomod2nix 是它的继任者，直接拥抱 Go modules，每依赖单独
  NAR hash 并共享；
- 我们 zhyi-packages 用 nixpkgs `buildGoModule`，两者都不需要。

## 5. 参考

- [vgo2nix](https://github.com/nix-community/vgo2nix)
- [gomod2nix 学习笔记](./gomod2nix.md)
