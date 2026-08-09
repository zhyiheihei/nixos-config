# flakelight-darwin 学习笔记

## 1. 是什么

`flakelight-darwin` 是 gkze/flakelight-darwin 的 fork（MIT，0
star，Nix）：给 [flakelight](https://github.com/nix-community/flakelight)
（已学）加的 **nix-darwin 支持模块**。compare 显示与上游
**完全一致**（0 ahead / 0 behind），是纯镜像 fork。

## 2. 功能

- `flakelight-darwin/darwinModules.nix`：把 nix-darwin 模块暴露成
  flakelight 输出；
- `darwinConfigurations.nix`：用 `inputs.nix-darwin.lib.darwinSystem`
  生成 `darwinConfigurations`；
- flake 只支持 `aarch64-darwin` / `x86_64-darwin`，`nix-darwin`
  input follows flakelight 的 nixpkgs；
- `templates/` + `tests/`：示例与 nix-darwin VM/求值测试。

## 3. 对我们仓库的启发

- 我们没有 Darwin 主机，不引入；
- 它是“flakelight 模块”的样例：像 flake-parts 模块一样，把
  nix-darwin 集成做成可复用输出；
- fork 与上游一致时按镜像记录即可。

## 4. 参考

- [flakelight-darwin](https://github.com/nix-community/flakelight-darwin)
