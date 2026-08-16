# mavenix 学习笔记

## 1. 是什么

`mavenix` 是 icetan 做的“用 Nix 确定性构建 Maven 项目”的工具：
类似 cargo2nix/npmlock2nix 的思路，先把 Maven 依赖锁进
`mavenix.lock`（路径 + sha1），再在 Nix 里组一个本地 Maven 仓库，
最后完全离线 `mvn package`。50 star，Unlicense，2022-02 后基本
停更。

工作流：

```sh
mvnix-init                # 生成 default.nix 模板
mvnix-update              # 生成 mavenix.lock
nix-build                 # 离线构建
```

也支持打包第三方项目：

```sh
mvnix-init -S 'fetchTarball "http://github.com/traccar/traccar/tarball/v4.2"'
mvnix-update && nix-build
```

## 2. mvnix-init / mvnix-update

`mvnix-init` 把仓库内的 `default-tmpl.nix` 模板渲染成项目
`default.nix`，默认用 `fetchTarball` 拉 mavenix 自身
（`-s` 可改成内嵌 `mavenix.nix` standalone 模式）。

`mvnix-update` 的流程：

1. 通过 `nix-instantiate --eval --strict --json` 取 derivation 的
   `mavenixMeta`（deps、emptyRepo、settings、infoFile、srcPath）；
2. 搭一个空 Maven 仓库（把已有 drvs 的依赖 symlink 进去）；
3. 在纯 nix-shell 里跑 `mvn install`（跳过测试）再
   `dependency:go-offline`；
4. 用 `help:effective-pom` + `xq` 解析出 groupId/artifactId/version
   和 submodules，从本地仓库扫描 `.repositories` 文件得到每个依赖
   的 path 和 sha1，写 `mavenix.lock`；
5. `jq -S` 排序输出，保证 lock 文件稳定。

## 3. buildMaven 与 mkRepo

`mavenix.nix` 导出的 `buildMaven` 是核心 builder：

- `mkRepo` 用 `runCommand` 组装本地仓库：
  - 普通依赖：`fetchurl`（sha1，带多镜像 urls）后按路径 symlink；
  - `authenticated` 依赖：`requireFile`（人工提供，不自动下载）；
  - Maven 元数据：`writeText` 写 XML，用 `xq` 展开 snapshot
    版本链接；
  - 递归合并其他 mavenix derivation 的 `mavenix.lock` 依赖
    （`transDeps` / `transMetas` / `transRemotes`）；
- 构建 derivation：nativeBuildInputs 是 `maven'`（带
  `--settings` wrapper）+ `ensureNewerSourcesHook { year = "1980" }`
  （对抗 Maven 时间戳确定性）；
- phases：`check`（`mvn test`）、`build`（`mvn package
  -DskipTests`）、`install`（把 jar/war、pom、properties、
  metadata 拷进 `share/java`）、`mavenixDistPhase`（把 lock 拷进
  `share/mavenix/`，供下游 drv 复用）；
- `mvn` 统一加 `--offline --batch-mode -Dmaven.repo.local=... -nsu`。

## 4. Flake / overlay / CLI

- flake 输出 `mavenix-cli` 包和 app，overlay 提供 `buildMaven` +
  `mavenix-cli`；
- CLI 用 `wrapProgram` 注入模板、`mavenix.nix` 路径、版本、PATH；
- 无 GitHub Actions；只有 `release.nix` 作为打包入口；
- `default.nix` 把 nixpkgs 钉在 2019-12 的 revision，模板里注释
  提示可用自己的 nixpkgs 覆盖。

## 5. 对我们仓库的启发

- 我们不打 Java 项目，不引入；
- 它和 autofirma-nix 的“Maven 依赖 FOD”路线互为对照：mavenix
  是“一个 lock 文件管全部依赖 + 离线 mvn”，autofirma-nix 是
  “go-offline 缓存做成 recursive FOD”。若 zhyi-packages 以后要
  打包 Java，优先参考后者（更贴近 nixpkgs 现代做法）；
- `ensureNewerSourcesHook` 和“重置时间戳”是 Java 构建确定性的
  通用手段，autofirma-nix 的 pom-tools 也做了同样的事。

## 6. 参考

- [mavenix](https://github.com/nix-community/mavenix)
