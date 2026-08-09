# .github（组织设置仓库）学习笔记

## 1. 是什么

`nix-community/.github` 是 zowoq 维护的“组织默认 GitHub 设置”仓库
（1 star，无 license，2025-09 仍有更新）：存放 GitHub 组织级
community health 文件，所有没有自带这些文件的仓库会自动继承。

## 2. 内容

- `CODE_OF_CONDUCT.md`：临时行为准则（说明等 NixOS Foundation 定稿
  后沿用），强调互相尊重与升级路径（警告 → 临时封禁 → 永久
  封禁），联系 admin@nix-community.org；
- `SECURITY.md`：漏洞报告指向 nix-community.org/security；
- `FUNDING.yml`：GitHub Sponsors（nix-community）+ Open Collective；
- `README.md`：一句话说明 + GitHub 官方文档链接。

## 3. 对我们仓库的启发

- 我们仓库也可受益于这套组织默认文件（例如安全策略直接生效）；
- 它是“org 级治理的零成本入口”：不用每个仓库复制 CoC/SECURITY，
  放 `.github` 即全局继承；
- 和 rfc39-record、projects 一样属于治理/流程类仓库。

## 4. 参考

- [nix-community/.github](https://github.com/nix-community/.github)
