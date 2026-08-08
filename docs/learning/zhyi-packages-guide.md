# zhyi-packages 复刻指南（包补充篇）

本文是整个 Nix 体系的“包补充”部分，主仓库是
[`./nix-replication-guide.md`](./nix-replication-guide.md)
描述的 `nixos-config`。本文件只负责 `zhyiheihei/zhyi-packages`：以复刻
[xddxdd/nur-packages](https://github.com/xddxdd/nur-packages) 为路径，掌握
“自用 NUR 包仓库”这一层，并最终融入 NUR、Attic 与自动更新生态。

## 1. 为什么以 xddxdd/nur-packages 为蓝本

xddxdd/nur-packages 是目前结构最完整、工作流最成熟的个人 NUR 仓库之一：

- 使用 flake-parts、devshell、treefmt、pre-commit 组织开发体验；
- 使用 nvfetcher 和 `_sources` 统一管理上游源码；
- 使用 `pkgs/default.nix` + `helpers/group.nix` 分组加载包；
- 使用 `_meta` 生成 README 和缓存说明；
- 使用 GitHub Actions 同时做 NUR 求值、meta 检查、缓存上传和自动更新；
- 还带有 colmena hive、NixOS modules、Cuda、pinned nixpkgs 等进阶能力。

复刻它，等于把“个人 NUR 仓库”和“NixOS 基础设施”两套知识一起学会。

## 2. 当前仓库状态（2026-08-08）

- 分支：`main`，最新提交 `cc54ccc`；
- 包：`uncategorized` 9 个，`python3Packages` 11 个，共 20 个可构建属性；
- 缓存：Attic，`https://attic.zhyi.xin/lantian`；
- 更新：`auto-update.yml` 每天 UTC 20:13 触发；
- CI：`check-package-meta` 已绿；`test-nur-eval` 仍红，等待 NUR 注册 PR
  [nix-community/NUR#1197](https://github.com/nix-community/NUR/pull/1197) 合并。

## 3. 上游对照

### 3.1 仓库结构与本地差异

| 区域 | 上游 xddxdd | 本地 zhyiheihei | 状态 |
| --- | --- | --- | --- |
| `flake.nix` | 含 colmena、NixOS modules、Cuda、pinned nixpkgs、python overlay | 精简版，只保留 packages/overlay | 有差距 |
| `overlay.nix` | 同时集成 python3Packages overlay | 只转发 `pkgs` | 有差距 |
| `flake-modules/` | 含 `auto-colmena-hive-*`、`modules-test-nixos-config` | 无 | 有差距 |
| `helpers/meta.nix` | Attic + Cachix | 仅 Attic | 有差距 |
| `tools/update_sources.py` | 与本地一致 | 一致 | 已对齐 |
| `tools/postprocess_nvfetcher.py` | 与本地一致 | 一致 | 已对齐 |
| `tools/check_package_meta.py` | 要求 `xddxdd` | 要求 `zhyiheihei` | 仅用户名差异 |
| `flake-modules/_internal/commands.nix` | `update-hashes` 限定三个目录 | 用 `find pkgs` 通用化 | 合理适配 |
| `flake-modules/_internal/commands.nix` | nur-combined 全量 clone | nur-combined 加 `--depth=1` 浅克隆 | 性能适配，语义不变 |
| `.github/workflows/build.yml` | `update?repo=xddxdd` | `update?repo=zhyiheihei` | 仅名字差异 |
| `.github/workflows/auto-update.yml` | bot 为 `xddxdd-bot` | bot 为 `zhyiheihei-bot` | 仅名字差异 |
| `pkgs/` | kernel-modules、lantian-customized、nvidia-grid 等 | 仅 python/uncategorized | 包规模差异 |
| `LICENSE` | MIT | 已添加 MIT（保留上游版权） | 已对齐 |
| NUR 注册 | 已注册 | PR #1197 已开，checks 全绿 | 等待合并 |

### 3.2 与 nix-community/NUR 的关系

`nix-community/NUR` 不是“应用包仓库”，而是所有个人 NUR 仓库的注册表：

- `repos.json`：登记每个仓库的 `github-contact` 和 `url`；
- `repos.json.lock`：锁定每个仓库的 commit 和 sha256；
- `bin/nur update`：抓取所有注册仓库并求值；
- `nix-community/nur-combined`：把每个仓库的表达式合并进 `repos/<用户名>`；
- `nix-community/nur-search`：基于 nur-combined 生成 `nur.nix-community.org` 搜索。

所以“完全融入 Nix”的第一步不是写代码，而是把仓库注册进 NUR 注册表。

## 4. 当前为什么红

### 4.1 `test-nur-eval`

`nix run .#nur-check` 的流程是：

1. clone `nix-community/NUR`；
2. 把本地 `repos.json` 复制进 NUR；
3. `bin/nur update` 更新并锁定 zhyiheihei；
4. `bin/nur eval` 本地求值（已 OK）；
5. clone `nix-community/nur-combined` 并执行 `bin/nur index nur-combined`。

失败发生在第 5 步：

```text
error: path 'h9w5...-source.drv' is not valid
failed to evaluate zhyiheihei
```

原因：`nur-combined` 里没有 `repos/zhyiheihei` 目录。`repoSource.nix` 找不到本地目录时
会退回从 GitHub `fetchzip`，而 index 阶段不允许现场实化源码。注册进 NUR 后，NUR 的
`combine` 流程会把我们的源码目录合进 nur-combined，这个错误自然消失。

### 4.2 `check-package-meta`

上一次失败里有两类问题：

1. `moviepilot` 的 `finalAttrs` 被自动补全误判，已通过手工加 `changelog` 修复；
2. 大量 python 包缺少 `meta.maintainers`。

`check_package_meta.py` 要求每个新包至少一个 maintainer，且 GitHub 用户名必须是
`zhyiheihei`。已为 `aioshutil`、`cn2an`、`jieba-next`、`pinyin2hanzi`、
`proces`、`pyromark`、`telegramify-markdown`、`torrentool`、`zhconv-rs`
补齐 `meta.maintainers`，并已由 GitHub Actions 的 `check-package-meta` job
验证通过。

## 5. 复刻路线

### 阶段 0：读懂仓库

逐个文件回答“为什么存在”：

- `flake.nix`：输入、输出、flake-parts 模块；
- `flake-modules/`：devshell、treefmt、pre-commit、commands、meta；
- `helpers/group.nix`：callPackage、分组、sources 注入；
- `helpers/nvfetcher-loader.nix`：版本规范化；
- `nvfetcher.toml`：每个包的 fetch/src 来源；
- `_sources/generated.nix`：生成结果，不要手改；
- `tools/update_sources.py`：nvchecker + prefetch 的更新实现；
- `pkgs/`：每个包的实际 Nix 表达式；
- `.github/workflows/`：CI 与自动更新；
- `repos.json`：nur-check 用的“自注册表”。

交付物：能不看文档讲出 `nix run .#update`、`nix run .#nur-check`、
`tools/check_package_meta.py` 各自做了什么。

### 阶段 1：补齐合规

- 添加 MIT `LICENSE`（已添加，满足 NUR PR 模板要求）；
- 给 9 个 python 包补 `meta.maintainers`（已补齐）；
- 给预编译二进制包补 `meta.sourceProvenance`（`vaults3` 已补
  `lib.sourceTypes.binaryNativeCode`）；
- 检查每个包是否有 `description`、`homepage`、`license`、`mainProgram`；
- `tools/check_package_meta.py` 已由 GitHub Actions 验证通过。

### 阶段 2：注册 NUR

1. fork `nix-community/NUR`；
2. 修改 `repos.json`：

```json
{
  "repos": {
    "zhyiheihei": {
      "github-contact": "zhyiheihei",
      "url": "https://github.com/zhyiheihei/zhyi-packages"
    }
  }
}
```

3. 运行 `./bin/nur format-manifest` 保证排序；
4. 只提交 `repos.json`，不提交 `repos.json.lock`；
5. 向 `nix-community/NUR` 开 PR；
6. 当前 PR 为 [nix-community/NUR#1197](https://github.com/nix-community/NUR/pull/1197)，
   两个检查均通过，等待合并；
7. PR 合并后重跑我们的 Build workflow。

注册后，`test-nur-eval` 应全绿，`nur-update` 的 webhook 才有意义。

### 阶段 3：对齐上游能力

如果要“完全学会作者这一套”，建议逐步把本地删掉的进阶能力补回来：

- `overlay.nix` 中集成 `python3Packages` override，和上游一致；
- `flake.nix` 增加 `pkgsWithCuda`、`legacyPackagesWithCuda`、pinned nixpkgs；
- 引入 `auto-colmena-hive` 模块，把 NixOS 机器也纳入同一个 flake；
- 增加 `modules/`，从简单的 `nix-cache-attic` 开始复刻上游 NixOS modules；
- 缓存同时配 Attic + Cachix，学习上游“多缓存冗余”的运维思路。

每补一块，先读上游对应文件，再自己重写一遍，不要直接 copy。

### 阶段 4：学会生态工具

- `nix-init`：从 URL 生成新包骨架；
- `nurl`：生成 fetcher 和 hash；
- `nixpkgs-update`：理解 nixpkgs 的自动更新与 PR 流程；
- `nix-index`：排查“哪个包提供这个文件”；
- 语言生态打包：见 [language-packaging.md](./language-packaging.md)；
- `nixos-anywhere`/`disko`/`colmena`：学会系统安装与部署；
- `nix-community/infra`：理解别人怎么管理一组 NixOS 机器。

### 阶段 5：反哺 nixpkgs

当某个包不再只属于个人自用，可以走 nixpkgs 流程：

1. 用 `nix-init` 生成表达式；
2. 用 `nixpkgs-update` 验证更新；
3. 提交 PR 到 NixOS/nixpkgs；
4. 若合并，则从本仓库删除，避免 NUR 与 nixpkgs 重复。

## 6. 验证清单

- [ ] 本地 `git status` 干净；
- [x] `tools/check_package_meta.py` 通过（GitHub Actions 已验证）；
- [ ] 远端 `nix run .#nur-check` 通过；
- [ ] `nix-community/NUR` 注册 PR 已合并；
- [ ] Build workflow 三个 job 全绿；
- [ ] auto-update 能自动提交 `_sources`；
- [ ] `nur.nix-community.org` 能搜到我们的包；
- [ ] Attic substituter 在 NixOS 上可用；
- [ ] 能解释 `flake.nix`、`helpers/group.nix`、`nvfetcher.toml`、workflows 的每一层。

## 7. 参考仓库

- [xddxdd/nur-packages](https://github.com/xddxdd/nur-packages)
- [nix-community/NUR](https://github.com/nix-community/NUR)
- [nix-community/nur-packages-template](https://github.com/nix-community/nur-packages-template)
- [nix-community/nur-combined](https://github.com/nix-community/nur-combined)
- [nix-community/nur-update](https://github.com/nix-community/nur-update)
- [nix-community/nur-search](https://github.com/nix-community/nur-search)
- [nix-community/nix-init](https://github.com/nix-community/nix-init)
- [nix-community/nixpkgs-update](https://github.com/nix-community/nixpkgs-update)
- [nix-community/infra](https://github.com/nix-community/infra)
