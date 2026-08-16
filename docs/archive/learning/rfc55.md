# rfc55 学习笔记

## 1. 是什么

`rfc55` 是 NixOS [RFC 55](https://github.com/NixOS/rfcs/blob/master/rfcs/0055-retired-committers.md)
（“退休不活跃 nixpkgs committer”）的实现脚本：用 PyGithub 找出
过去一年没提交的 nixpkgs committer。5 star，无 license，Python，
已归档——README 写明同等功能已并入
[nixos/nixpkgs-committers](https://github.com/nixos/nixpkgs-committers)。

## 2. 逻辑

```sh
export GITHUB_TOKEN=<token>   # 需要 read:org scope
nix-build && ./result/bin/inactive-maintainers
```

- 列出 `nixos` org 的 `nixpkgs-committers` team 成员（按登录名
  排序）；
- 对每个人查 nixpkgs 自**去年 1 月 1 日**以来的 commits；
- 没有提交的打印成 markdown 条目（带 commits 链接），供人工
  处理；
- 黑名单 `GrahamcOfBorg`（bot）；`lf-` 因 GitHub API 已知问题
  单独提示人工核对。

## 3. 工程

- `setup.py` / `setup.cfg`：console script `inactive-maintainers`，
  mypy 严格配置；
- `default.nix`：`buildPythonPackage` + PyGithub，checkPhase 跑
  mypy；CI 是 `nix-build`；Mergify 队列合依赖 PR。

## 4. 对我们仓库的启发

- 我们不需要 nixpkgs 治理脚本，不引入；
- 它演示了“用 GitHub API 批量查团队/提交”的简单 bot 写法，
  和 label-approved（已学）同类；
- “小脚本被更正式的仓库/平台取代后归档”是常见生命周期，看
  README 的迁移提示即可。

## 5. 参考

- [rfc55](https://github.com/nix-community/rfc55)
