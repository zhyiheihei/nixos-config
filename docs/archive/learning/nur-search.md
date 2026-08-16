# nur-search 学习笔记

## 1. 是什么

`nur-search` 是 NUR 的包搜索站点源码，托管在
[nur.nix-community.org](https://nur.nix-community.org)（实际生成的
HTML 在 `gh-pages` 分支）。维护者 Pandapip1，44 star，Hugo 静态站 +
Python 生成脚本；搜索和文档页靠 NUR 主仓库的 evaluation 数据驱动。

## 2. 构建流程

```bash
nix-shell    # hugo + python3 + requests
make all     # generate_pages.py && hugo
```

`scripts/generate_pages.py`：

1. 读 `data/packages.json`（由 NUR 仓库 CI 的
   `ci/update-nur-search.sh` 生成，包含所有 repo 的包元数据）；
2. 按 `_repo` 分组，为每个仓库生成一个 markdown 页，表格列为
   `Name | Attribute | Description`：name 链到 homepage，attribute
   链到 `meta.position`（源码位置），description 去掉换行；
3. 下载 NUR README 作为 `/documentation/` 页面；
4. 写 `data/stats.json`（`repo_count` / `pkg_count`），首页显示
   NUR 统计。

站点是 Hugo + docdock 主题（submodule），`config.toml` 输出
HTML/RSS/JSON，layouts 覆盖了 docdock 的 header/搜索框
（lunr.js 客户端搜索）和导航下拉。

## 3. CI：数据更新与发布

两个 workflow：

- `update.yml`：由 NUR 主仓库发 `repository_dispatch`
  （`nur_update`）或手动触发；checkout NUR、nur-combined
  （含递归 submodules）和 nur-search，用 GitHub App token 跑
  `ci/update-nur-search.sh` 生成新 `packages.json`，rebase 后
  `CasperWA/push-protected` 推回 main；
- `pages.yml`：push 到 main 后装 Hugo extended 0.128.0，
  `make all`，把 `public/` 传到 GitHub Pages（`configure-pages` +
  `deploy-pages`）。

另用 renovate 管依赖更新。

## 4. 对我们仓库的启发

- 我们的 zhyi-packages 已注册 NUR，nur-search 就是展示它包的站点；
- 这个仓库展示了“主仓库 CI → repository_dispatch → 数据更新 →
  自动推 main → 再触发站点重建”的两段式自动化，适合我们
  以后做“数据仓库 + 展示站”时照搬；
- NUR 包元数据本身是搜索的全部输入，说明在 NUR 里把 `meta` 写全
  （description/homepage/position/license）不只是规范要求，也直接
  决定搜索站点的展示质量。

## 5. 参考

- [nur-search](https://github.com/nix-community/nur-search)
- [NUR](https://github.com/nix-community/NUR)
