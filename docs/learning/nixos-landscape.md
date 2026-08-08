# nixos-landscape 学习笔记

## 1. 是什么

`nixos-landscape` 是 cafkafk 维护的“Nix/NixOS 生态全景图”网站
（[landscape.nixlang.wiki](https://landscape.nixlang.wiki)），基于
CNCF 的 [landscape2](https://github.com/cncf/landscape2) 软件，部署在
nixlang.wiki 的 Kubernetes 集群。33 star，AGPL-3.0，2024-04 后
基本停更。

仓库结构：

- `data.yml`：生态条目数据（分类/子分类/项目，含 homepage、
  repo、logo、maturity）；
- `settings.yml`：landscape2 配置（foundation=NixLang、配色、
  groups、featured_items 按 community/official/commercial 排序、
  QR code、截图宽度）；
- `guide.yml`：向导内容（目前多是 lorem ipsum 占位）；
- `logos/` + `build/`：logo 和生成好的静态站输出；
- `landscape2`：Rust CLI（`src` 是 nixlang-wiki fork 的
  landscape2 submodule）。

## 2. 构建与部署

`justfile` 定义：

```sh
just build        # landscape2 build --data-file data.yml ...
just serve        # landscape2 serve --landscape-dir build
just buildAndPushContainer && just deploy   # 推到 ghcr/DO registry + kubectl rollout
```

- `rust-build` / `rust-build-release`：本地 cargo 编译 landscape2
  CLI；
- Dockerfile 两段：`rust:1-alpine` 编译 CLI（带 chromium，用于自动
  截图），`alpine` 最终镜像装 `build/` 静态站，`serve --addr 0.0.0.0:80`。

## 3. Flake 质量门禁

- `treefmt.nix`：alejandra / statix / deadnix / rustfmt / taplo /
  yamlfmt；
- `nix flake check`：pre-commit-hooks 复用 treefmt 配置（过滤掉
  yamlfmt），另加 convco（conventional commits）和 `reuse lint`
  （SPDX 头检查）；
- 仓库大量文件带 `SPDX-FileCopyrightText` 头，REUSE 合规；
- devShell 只有 `just` 和 `reuse`；无 GitHub Actions workflows。

## 4. 对我们仓库的启发

- 我们不需要生态地图站，不引入；
- “YAML 数据 + landscape2 生成静态站”比手写 HTML 维护生态列表
  更干净，未来若做 NixOS 生态/模块索引可以参考；
- `settings.yml` 的 featured items（按 maturity 高亮）和
  groups（多 tab）是数据驱动导航的好设计；
- REUSE + pre-commit + treefmt 的组合也是我们 docs 仓库可借鉴的
  质量基线。

## 5. 参考

- [nixos-landscape](https://github.com/nix-community/nixos-landscape)
- [CNCF landscape2](https://github.com/cncf/landscape2)
