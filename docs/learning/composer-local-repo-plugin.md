# composer-local-repo-plugin 学习笔记

## 1. 是什么

`composer-local-repo-plugin` 是 drupol 写的 Composer 2 插件（MIT，
3 star，PHP，2024-03 后基本停更）：从已有 `composer.lock` 生成
**本地 `composer` 类型仓库**（Packagist 同款结构：`packages.json` +
每个包版本的源码目录），让项目可以离线、可重复地 `composer
install`。

它最初就是为了 Nix 打包 PHP 包而写（[nixpkgs PR
#225401](https://github.com/NixOS/nixpkgs/pull/225401)），灵感来自
fossar/composition-c4。

## 2. 两个命令

```sh
# 生成仓库 + packages.json（Composer 2.7 起 repository 方式废弃）
composer build-local-repo /path/to/repo

# 生成仓库 + 更新后的 composer.lock（推荐）
composer build-local-repo-lock /path/to/repo
```

选项：`-r`（只要仓库）、`-m`（只要 manifest / composer.lock）、
`-p`（打印）、`--no-dev`（跳过 dev 依赖）。

## 3. 服务层

- `RepoBuilder`：按 lock 里每个包用 Composer download manager 下载
  到 `destDir/<name>/<version>`；
- `ManifestBuilder`：把包条目的 source/dist 改成 `type: path`
  并指向本地目录，保留完整包信息（autoload/bin 等），写
  `packages.json`；
- `ComposerLockBuilder`：同样把 lock 里条目改成 path 源，写更新
  版 `composer.lock`；
- `LocalBuilder`：遍历 lock 的 `packages` / `packages-dev`。

## 4. 离线安装流程

1. 生成仓库 + 拷贝更新后的 composer.lock；
2. 关网络（`COMPOSER_DISABLE_NETWORK=1`）；
3. `composer install`；
4. 需要复制而不是 symlink 时设 `COMPOSER_MIRROR_PATH_REPOS=1`。

## 5. 对我们仓库的启发

- 我们不打 PHP，不引入；nixpkgs 的 `buildComposerProject` 等
  helper 已把 fetchComposerArtifacts 做成独立步骤；
- “把 lockfile 的远端源改写成本地 path 源”是让包管理器离线构建
  的通用思路，和 mavenix（离线 mvn repo）同类；
- zhyi-packages 未来若补 PHP 生态，这个插件是 nixpkgs 现成依赖，
  不用自己实现。

## 6. 参考

- [composer-local-repo-plugin](https://github.com/nix-community/composer-local-repo-plugin)
