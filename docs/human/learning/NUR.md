# NUR 生态与注册（学习笔记）

`NUR`（Nix User Repository）是 **Nix 社区个人包仓库的注册表和聚合层**（MIT，1917 star）。
和 nixpkgs 不同，NUR 里的包由各仓库作者自行维护，**不经过 Nixpkgs 成员 review**；
NUR 只负责登记、锁定 commit、求值检查并聚合出 `nur.repos.<user>.<pkg>` 命名空间。

## 生态链（核心仓库）

- `nix-community/NUR`：注册表 + 工具。`repos.json` 登记个人仓库，
  `repos.json.lock` 锁定 commit 与 sha256，`bin/nur` 负责 update/eval/index。
- `nix-community/nur-packages-template`：个人 NUR 仓库模板，包含 CI
  （159 star，用 GitHub "Use this template" 而不是 fork）。
- `nix-community/nur-combined`：把所有 NUR 仓库表达式合并为 `repos/<用户名>`。
- `nix-community/nur-update`：`POST /update?repo=<name>` 通知 NUR 有新版本。
- `nix-community/nur-search`：基于 nur-combined 生成 `nur.nix-community.org` 搜索。

## 使用

```nix
# flake input
nur.url = "github:nix-community/NUR";
```

然后可以用：

- `pkgs.nur.repos.<user>.<pkg>`（overlay）；
- `nur.legacyPackages.<system>.repos.<user>.<pkg>`；
- `nur.repos.<user>.modules.*` 导入 NixOS / Home Manager module。

## 注册流程

1. 仓库根目录要有返回包集合的 `default.nix`，依赖从传入的 `pkgs`
   参数取，不要 `with import <nixpkgs> {};`；
2. 内容按 MIT 等开源许可发布；
3. 向 `nix-community/NUR` 开 PR，只改 `repos.json`：

```json
{
  "zhyiheihei": {
    "github-contact": "zhyiheihei",
    "url": "https://github.com/zhyiheihei/zhyi-packages"
  }
}
```

4. 运行 `./bin/nur format-manifest`；
5. 只提交 `repos.json`，不提交 `repos.json.lock`；
6. 开 PR，等待 NUR CI 与维护者合并。

## 为什么注册后 test-nur-eval 才绿

`nur-check` 最后会 clone `nur-combined` 并执行 `bin/nur index`。`repoSource.nix`
优先使用 `nur-combined/repos/<name>` 本地目录；未注册时该目录不存在，只能退回
从 GitHub fetchzip，导致 `path ...-source.drv is not valid`。

## 模板结构（nur-packages-template）

- 根 `default.nix`：接收 `pkgs` 参数（允许默认 `<nixpkgs>`），返回包集合；
  `lib`、`overlays`、`nixosModules`、`homeModules`、`darwinModules`、
  `flakeModules` 是特殊保留属性；
- `pkgs/<name>/default.nix`：每个包一个目录；`overlay.nix` 把非保留属性
  作为 overlay 输出；
- `ci.nix`：筛选可构建/可缓存包——排除 `meta.broken`、非自由 license、
  `preferLocalBuild`，展开 `recurseForDerivations` 和所有 outputs；
- `flake.nix`：导出 `legacyPackages` / `packages` / modules。

### CI 模板（build.yml）

- matrix：三个 nixpkgs channel（nixpkgs-unstable、nixos-unstable、nixos-26.05）；
- 可选 Cachix（`CACHIX_SIGNING_KEY` / `CACHIX_AUTH_TOKEN`）；
- `nix-env -f . -qa` 做 restrict-eval 求值检查；
- `nix-build-uncached ci.nix -A cacheOutputs` 构建缓存包；
- 最后 `curl -XPOST https://nur-update.nix-community.org/update?repo=<name>`
  通知 NUR 有新版本。

## 我们的落点

- `zhyi-packages` 已按规范注册：PR
  [nix-community/NUR#1197](https://github.com/nix-community/NUR/pull/1197)
  已开且 checks 绿，等合并后重跑 `test-nur-eval`。
- 走的是 xddxdd 的 NUR 结构（pkgs + flake-modules + tools + nvfetcher），
  不是直接照抄模板，但都满足同一份 NUR 契约。
- 相关文件：`zhyi-packages/flake-modules/_internal/commands.nix` 的
  `nur-check`、`.github/workflows/build.yml` 的 `test-nur-eval` /
  `check-package-meta` / `update-nur`、`zhyi-packages/repos.json`。
- `zhyi-packages` 只作为包补充仓库存在，不放学习文档，只保留 AGENTS.md；
- 模板 `ci.nix` 的筛选逻辑（broken/unfree/preferLocalBuild）值得参考，
  我们 build.yml 的 `check-package-meta` 在做类似检查。
- NUR 价值是低门槛分享包，但也意味着用户要自己审查表达式；对外暴露前应
  保证 `meta` 完整（license/maintainers/homepage）。

## 参考

- [NUR](https://github.com/nix-community/NUR)
- [nur-packages-template](https://github.com/nix-community/nur-packages-template)
- [zhyi-packages 复刻指南](zhyi-packages-guide.md)
