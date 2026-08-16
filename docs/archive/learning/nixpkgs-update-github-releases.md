# nixpkgs-update-github-releases 学习笔记

## 1. 是什么

`nixpkgs-update-github-releases`（源自 Synthetica9，CC0-1.0，5
star，Python，2026-02 仍在维护）是
[nixpkgs-update](https://github.com/ryantm/nixpkgs-update) 的
**GitHub releases 数据源**：扫描 nixpkgs 里所有包，比较其当前版本
与上游 GitHub 最新 release，输出
`<attr> <当前版本> <新版本> <releases 页 URL>` 供更新工具消费。

## 2. 数据加载

- `loadVersions()`：`nix-env -qaP` 列出全部包名，再用
  `loadMetaFromPath.nix`（`tryEval` + `deepSeq`）安全求值每个包的
  `version` 与 `src.meta.homepage` / `src.urls` / `meta.homepage`；
- 用 `nixpkgs=master.tar.gz` 作为求值源；下午时段反转遍历顺序，
  分散 GitHub API 压力。

## 3. 版本比较

对每个包：

1. 从 homepage 用正则解析 `github.com/<owner>/<repo>`（过滤
   wiki/downloads/archive 等路径）；
2. GitHub API 分页拉 releases，跳过 prerelease 和名字含
   nightly/develop/rc/alpha/beta/snapshot/testing 的版本；
3. `stripRelease` 去掉 `v` / `version` / `release` / `stable` /
   repo 名等前缀（大小写和连接符变体）；
4. 用 `libversion.version_compare` 确认比当前新；`unstable-YYYY-MM-DD`
   按日期比较；
5. 输出更新行。还跳过 `python3*` 和 `typstPackages*`（有专属更新
   脚本/集合）。

## 4. API 健壮性

- `getEndpoint`：处理 500（指数退避）、404、451、403 限流
  （睡到 `X-RateLimit-Reset`）、空 JSON 重试；用
  `CacheControl` + 文件缓存，打印缓存命中统计；
- 认证：`API_TOKEN` 环境变量或 `API_TOKEN` 文件（
  `<username>:<token>`）。

## 5. 对我们仓库的启发

- 我们不跑 nixpkgs-update，不引入；
- 它和 nixpkgs-terraform-providers-bin（已学）一样是“扫包集 →
   查上游 API → 输出更新清单”的数据管线，但只做“报告”不自动
   提交；
- “tryEval 遍历整个 nixpkgs 属性树收集元数据”和
  nixpkgs-swh 的 find-tarballs 是同类技巧，可复用。

## 6. 参考

- [nixpkgs-update-github-releases](https://github.com/nix-community/nixpkgs-update-github-releases)
