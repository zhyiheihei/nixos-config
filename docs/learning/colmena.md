# colmena 学习笔记

## 1. 是什么

`colmena`（zhaofengli 维护，MIT，2299 star）是一个 **Rust 写的
简单、无状态 NixOS 部署工具**，设计上模仿 NixOps / morph，但只做
“薄封装”：内部调用 `nix-instantiate` / `nix eval` / `nix-copy-closure`
等命令，支持多主机并行构建、复制和切换。

## 2. Hive 模型

在 `flake.nix` 里输出 `colmenaHive`：

```nix
colmenaHive = colmena.lib.makeHive {
  meta.nixpkgs = import nixpkgs { ... };
  defaults = { pkgs, ... }: { ... };  # 所有节点公共配置
  host-a = { nodes, ... }: { ... };   # 节点配置，可用 nodes.<name>
};
```

关键特性：

- `meta.nixpkgs` 全局 pin，也支持 `nodeNixpkgs` 按节点覆盖；
- `defaults` 批量应用公共模块；
- `deployment.targetHost` / `targetPort` / `targetUser` 控制 SSH；
- `deployment.tags` 支持 `colmena apply --on @tag` 和 glob
  （`--on '@infra-*'`）；
- 节点模块可以引用 `nodes.<other>.config`，做跨节点配置派生。

## 3. 命令

- `colmena build`：只构建；
- `colmena apply`：构建 + 复制 + 激活（默认 goal 是 boot 或
  switch）；
- `colmena apply-local` / `colmena send`：本地应用或只复制；
- `colmena eval`：对 hive 做 nix eval；
- `colmena introspect`：调试节点配置。

环境变量 `SSH_CONFIG_FILE` 可指定 ssh_config；需要 SSH key 登录，
不支持交互密码。

## 4. 工程细节

- 旧版本通过 `flake` 输出 `colmenaHive` 特殊属性；现在推荐在 flake
  里显式 import colmena input 并用 `colmena.lib.makeHive`；
- 每台节点一个 profile，`deployment.replaceUnknownProfiles` 控制
  是否覆盖本机 nix store 里没有的 profile（多人协作时建议关闭）；
- GitHub Actions 构建后推到 colmena.cachix.org。

## 5. 对我们仓库的启发

我们仓库就是 Colmena Hive 布局：`hosts/` 是唯一主机来源，
`Makefile` 的 `make build` / `make all` 按标签批量切换：

- 新增主机 = 新增 `hosts/<name>/` + `host.nix` 标签；
- 公共模块仍放 `nixos/<role>-components/`，避免在 host 里重复；
- `--on @tag` 的批量模型对应我们的 `server` / `client` / `pve`
  标签部署。

## 6. 参考

- [colmena](https://github.com/zhaofengli/colmena)
- [Colmena 手册](https://colmena.cli.rs/)
