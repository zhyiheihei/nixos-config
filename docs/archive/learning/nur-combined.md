# nur-combined 学习笔记

## 1. 是什么

`nur-combined` 是 NUR 所有个人仓库的“合并 checkout”：把注册表里的每个
仓库源码复制进 `repos/<用户名>/`，方便整体求值、共享 nixpkgs pin 和
缓存。当前 manifest 里有 551 个仓库，仓库源码整体体积很大（master
压缩包约 560MB），不适合逐文件学习，重点是它如何组织和更新。

## 2. 结构

- `repos.json`：从 `nix-community/NUR` 同步的注册表 manifest；
- `repos.json.lock`：每个仓库锁定的 `rev` + `sha256`；
- `repos/`：各仓库源码（供 `repoSource.nix` 优先使用本地路径）；
- `default.nix`：读 manifest，对每个仓库做 `tryEval`，求值失败的
  仓库以 warning 跳过；
- `lib/evalRepo.nix`：只把 `pkgs` 传给每个仓库的 `default.nix`，并
  拒绝已废弃的 `callPackage` 风格（会引发无限递归）；
- `lib/repoSource.nix`：优先用 `../repos/<name>`，否则按 GitHub/
  GitLab/普通 git 用 fetchzip/fetchgit 拉锁定的 revision。

## 3. 更新机制

- GitHub Actions `update.yml` 监听 `repository_dispatch` 的
  `nur_update`（由 NUR 上游触发），也支持手动 `workflow_dispatch`；
- 同时 checkout `nix-community/NUR` 和 `nur-combined`，运行 NUR 的
  `ci/update-nur-combined.sh` 同步 repos/lock，再推到受保护的
  main 分支。

## 4. 与我们的关系

- 我们的上游作者 `xddxdd` 的 `nur-packages` 已在合并集中；
- `zhyiheihei` 还没出现，等 NUR PR #1197 合并后，`nur_update` 会把它
  带进 nur-combined，`test-nur-eval` 才能稳定走本地 `repos/<name>`；
- 这就是 `../../human/learning/nur-chain.md` 里“注册后 test-nur-eval 才绿”的直接原因。

## 5. 对我们仓库的启发

- 求值大规模第三方 Nix 代码时，先 `tryEval` 再跳过、失败只给 warning，
  比整体硬失败更实用；
- “锁 manifest + 锁 revision/hash + 本地 checkout 优先”的结构适合
  批量同步场景。

## 6. 参考

- [nur-combined](https://github.com/nix-community/nur-combined)
- [NUR](https://github.com/nix-community/NUR)
