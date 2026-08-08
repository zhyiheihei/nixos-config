# NUR 生态链

## 核心仓库

- `nix-community/NUR`：注册表 + 工具。`repos.json` 登记个人仓库，
  `repos.json.lock` 锁定 commit 与 sha256，`bin/nur` 负责 update/eval/index。
- `nix-community/nur-packages-template`：个人 NUR 仓库模板，包含 CI。
- `nix-community/nur-combined`：把所有 NUR 仓库表达式合并为
  `repos/<用户名>`。
- `nix-community/nur-update`：`POST /update?repo=<name>` 通知 NUR 有新版本。
- `nix-community/nur-search`：基于 nur-combined 生成
  `nur.nix-community.org` 搜索。

## 注册流程

1. 仓库根目录有 `default.nix`，返回值是包集合；
2. 仓库内容按 MIT 发布；
3. 向 `nix-community/NUR/repos.json` 添加条目：

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

## 我们的落点

- `zhyi-packages/flake-modules/_internal/commands.nix` 的 `nur-check`
- `.github/workflows/build.yml` 的 `test-nur-eval` / `check-package-meta` /
  `update-nur`
- `zhyi-packages/repos.json`
