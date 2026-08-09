# label-approved 学习笔记

## 1. 是什么

`label-approved` 是 Artturin / wegank 维护的 nixpkgs PR 打标程序：
按批准人数给 PR 加
`12.approvals: 1` / `2` / `3+`，并在“包维护者批准”时加
`12.approved-by: package-maintainer`。15 star，pyproject 标注 MIT
（仓库无 LICENSE 文件），Python，2026-06 仍在维护。

动机：GitHub 不显示非 committer 的 approval，这个工具让非 committer
也能通过 review 帮 committer 把关。

## 2. 规则逻辑（cli.py）

对每个 open 非 draft PR：

1. 收集 reviews，按用户去重，最新状态为 APPROVED 才算批准
   （后续 CHANGES_REQUESTED 会撤销）；
2. 只在**最后一次 approved review 晚于最后一次 commit** 时更新
   label（否则 commit 后可能没被重新审）；
3. 维护者判定：`timelineItems` 里由 `nix-owners` 发起的
   `ReviewRequestedEvent` 的 reviewer 集合，与 approved users 求交；
   只在该 PR 有 GHA `Eval / Summary` 状态时更新——ofborg 的
   `ofborg-eval-check-maintainers` 2024-12-31 已下线，还在的说明
   PR 太旧，跳过；
4. 如果已经由 `github-actions` 打过 approval label，跳过，避免
   双写；
5. `--dry_run` 只打日志。

## 3. GraphQL 实现

- 一次 search 查 50 个 PR，metadata 含 labels / reviews /
  timelineItems / 最后一次 commit 时间与 CI 状态；
- label id 用 query 查一次缓存；增删 label 走 mutation；
- 请求间按 GitHub 建议 sleep，错误自动减半 batch size 重试，
  并记录 rate limit 剩余量；
- token 来源：`INPUT_GITHUB_TOKEN` → `GITHUB_BOT_TOKEN` →
  `GITHUB_TOKEN` → `gh auth token`。

## 4. 交付形态

- **GitHub Action**：`action.yml` 是 Docker action，输入
  `github_token` + `pr_number`，执行 `--single_pr`；
- **Dockerfile**：`nixos/nix` 里 `nix build` 后把 closure 拷进
  `FROM scratch`（和 docker-nix 同样的最小镜像套路）；
- **NixOS module**：`services.label-approved`，systemd timer 默认
  每 30 分钟跑，`DynamicUser` + `EnvironmentFile` 提供 token；
- flake：手动 `buildPythonApplication`（pyproject + poetry-core +
  PyGithub/requests/dateutil），`mypy --strict` 进 checkPhase；
  CI 在 ubuntu/macos 上跑 `nix-build` + `nix flake check`。

## 5. 对我们仓库的启发

- 我们不用 nixpkgs PR 打标，不引入；
- “用 GraphQL 批量爬 PR 元数据 + 幂等增删 label + rate limit
  感知”是 GitHub 自动化 bot 的完整范本；
- 同一逻辑同时做成 Action / 二进制 / NixOS 服务三种形态，说明
  “一个 CLI 多种交付”的组织方式很省事。

## 6. 参考

- [label-approved](https://github.com/nix-community/label-approved)
