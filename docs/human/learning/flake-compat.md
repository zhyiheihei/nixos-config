# flake-compat 学习笔记

## 1. 是什么

`flake-compat`（nix-community fork）让**不支持 flakes 的旧版 Nix**
也能使用 flake 项目：给定 `flake.nix` + `flake.lock`，它模拟
`builtins.fetchTree` 拉取全部输入，调用项目的 `outputs` 函数，并
把结果包成 `defaultNix` / `shellNix`。MIT，18 star，**已归档**：
README 明确说“不再维护，官方版在 NixOS/flake-compat”
（原作者 Eelco Dolstra 移交 NixOS 组织）。

## 2. 用法

在 flake 里加输入：

```nix
inputs.flake-compat.url = "github:nix-community/flake-compat";
```

然后写 `default.nix` 兼容壳：

```nix
{ system ? builtins.currentSystem }:
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  root = lock.nodes.${lock.root};
  inherit (lock.nodes.${root.inputs.flake-compat}.locked) owner repo rev narHash;
  flake-compat = fetchTarball { ... };
  flake = import flake-compat { inherit system; src = ./.; };
in
flake.defaultNix
```

`shell.nix` 同样写法，末尾换成 `shellNix`。

## 3. 实现要点（default.nix）

- `fetchTree` 按输入类型模拟：github（api tarball + narHash）、
  git（`builtins.fetchGit`）、path、tarball、gitlab；
- `allNodes` 遍历 lock 文件（version 5–7）：每个节点 import 它的
  `flake.nix`，解析 `follows`，把 `inputs // { self = result; }`
  传给 `outputs`，结果附上 `sourceInfo` / `_type = "flake"`；
- 没有 flake.lock 时退到 `callLocklessFlake`；
- 根源尝试用 `fetchGit` 清理（worktree/shallow 处理），并手工实现
  epoch 秒 → `%Y%m%d%H%M%S` 的格式化；
- `defaultNix` 兼容 `defaultPackage.${system}` 和
  `packages.${system}.default`；`shellNix` 再兼容
  `devShell` / `devShells.${system}.default`。

## 4. 变体与影响

- 本 flake 的 `flake.nix` 只导出 `lib = import ./.`；
- nixpkgs-terraform-providers-bin 的 `flake.lock.nix` 是我们已见过
  的“只返回 inputs”变体（把 flake 当 niv 用）；
- luarocks-nix、docnix 等仓库的 `shell.nix` 都靠它做非 flake
  兼容入口。

## 5. 对我们仓库的启发

- 我们全程用 flakes，不需要引入；
- 它是“旧工具链兼容层”的典型：不用改项目，只加一个适配入口；
  若以后 zhyi-packages 要支持非 flake 用户，可以直接抄这份
  `default.nix` 模板（或跟随官方 NixOS/flake-compat）。

## 6. 参考

- [nix-community/flake-compat](https://github.com/nix-community/flake-compat)
- [NixOS/flake-compat（官方）](https://github.com/NixOS/flake-compat)
