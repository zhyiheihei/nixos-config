# vulnix 学习笔记

## 1. 是什么

`vulnix` 是 Nix/NixOS 的 CVE 漏洞扫描器：检查 Nix store 里 live path 可达的
包，匹配 NVD 公开 CVE 数据库，输出受影响包和 CVSS 分数。

## 2. 工作原理

- 从 NIST NVD 拉取并缓存 CVE；
- 直接解析 `*.drv`；
- 用包名/版本启发式匹配 NVD product；
- 支持 whitelist 过滤误报；
- 能从 patch 文件名里的 CVE 编号自动识别“已修复”。

## 3. 用法

```sh
# 当前系统
vulnix --system

# 检查构建结果及其 closure
vulnix result/

# JSON 输出
vulnix --json /nix/store/my-derivation.drv
```

## 4. Whitelist

TOML 格式，按包名分组，可用 `cve`、`until`、`issue_url`、`comment` 约束：

```toml
["ffmpeg-3.4.2"]
cve = ["CVE-2018-6912"]
until = "2018-05-01"
comment = "等待 backport"
```

## 5. 对我们仓库的启发

我们可以把 `vulnix --system` 或对特定闭包扫描加入安全审计流程。它和
`nixpkgs-update` 的 CVE 报告是互补关系：前者扫当前闭包，后者在升级 PR 时
对比新旧版本。

## 6. 参考

- [vulnix](https://github.com/nix-community/vulnix)
