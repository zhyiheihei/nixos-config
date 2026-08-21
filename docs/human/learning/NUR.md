# NUR 学习笔记

## 1. 是什么

`NUR`（Nix User Repository）是 **Nix 社区个人包仓库的注册表和
聚合层**（MIT，1917 star）。和 nixpkgs 不同，NUR 里的包由各仓库
作者自行维护，**不经过 Nixpkgs 成员 review**；NUR 只负责登记、
锁定 commit、求值检查并聚合出 `nur.repos.<user>.<pkg>` 命名空间。

## 2. 核心文件

- `repos.json`：注册表，每项是 `用户名 -> { github-contact, url }`；
- `repos.json.lock`：CI 锁定的 commit 和 sha256（由维护流程生成，
  注册 PR 不手改）；
- `bin/nur`：Python CLI，负责 update / eval / index；
- `lib/evalRepo.nix`、`lib/repoSource.nix`：按锁文件 fetch 并求值
  每个仓库；
- `ci/`：Python 包 + 更新 nur-combined / nur-search 的脚本；
- `default.nix` / flake：把聚合结果暴露为 `nur.repos`。

## 3. 使用

```nix
# flake input
nur.url = "github:nix-community/NUR";
```

然后可以用：

- `pkgs.nur.repos.<user>.<pkg>`（overlay）；
- `nur.legacyPackages.<system>.repos.<user>.<pkg>`；
- `nur.repos.<user>.modules.*` 导入 NixOS / Home Manager module。

## 4. 注册规范

1. 仓库根目录要有返回包集合的 `default.nix`，依赖从传入的 `pkgs`
   参数取，不要 `with import <nixpkgs> {};`；
2. 内容按 MIT 等开源许可发布；
3. 向 `nix-community/NUR` 开 PR，只改 `repos.json`，用
   `./bin/nur format-manifest` 格式化；
4. 合并后 NUR CI 会生成 `nur-combined` 和搜索索引。

我们的 `zhyi-packages` 已按这个规范注册：PR
[nix-community/NUR#1197](https://github.com/nix-community/NUR/pull/1197)
已开且 checks 绿，等合并后重跑 `test-nur-eval`。

## 5. 对我们仓库的启发

- `zhyi-packages` 只作为包补充仓库存在，不放学习文档，只保留
  AGENTS.md；
- 注册成功前，`nur-check` 的 `bin/nur index nur-combined` 会失败，
  因为本地 `repos/<name>` 目录还不存在；
- NUR 的价值是低门槛分享包，但也意味着用户要自己审查表达式；
  我们对外暴露前应保证 `meta` 完整（license/maintainers/homepage）。

## 6. 参考

- [NUR](https://github.com/nix-community/NUR)
- [nur-chain 生态链笔记](nur-chain.md)
- [nur-packages-template](nur-packages-template.md)
