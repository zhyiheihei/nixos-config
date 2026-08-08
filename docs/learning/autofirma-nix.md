# autofirma-nix 学习笔记

## 1. 是什么

`autofirma-nix` 为西班牙政务数字服务工具套件提供 Nix 包、NixOS
模块和 Home Manager 模块，维护者 nilp0inter / panchoh / CesarGallego，
54 star，MIT：

- **AutoFirma**：数字文档签名 + 网页身份认证；
- **DNIeRemote**：把手机当西班牙身份证 NFC 读卡器；
- **Configurador FNMT-RCM**：申请安装西班牙皇家铸币厂证书。

```bash
nix run github:nix-community/autofirma-nix#dnieremote
nix flake new --template github:nix-community/autofirma-nix#nixos-module ./my-system
```

## 2. Flake 结构

- 三个上游源（`ctt-gob-es/clienteafirma` v1.9、
  `clienteafirma-external` v1.0.6、`jmulticard` v2.0）作为
  `flake = false` 的固定输入；
- 输出：`nixosModules` / `homeManagerModules`（三个子模块 + default
  合集）、`templates`（NixOS / HM-on-NixOS / HM standalone）、
  `packages`、`overlayAttrs`（flake-parts easyOverlay）、
  `checks`（NixOS 虚拟机测试 + HM 测试 + 单元测试）；
- `systems` 覆盖 x86_64-linux / aarch64-linux；DNIeRemote 和
  Configurador 因 openssl_1_1 等原因只做 x86_64；
- 文档是 mdbook，`nix build .#docs` 后发布 GitHub Pages。

## 3. AutoFirma 打包：Maven + FHS + truststore

`nix/autofirma/` 是核心，分三层：

1. **源码预处理**：用 `pom-tools`（一批脚本）在构建前改 pom.xml：
   Java 版本、包版本（`<rev>-autofirma-nix`）、外部依赖版本、
   删除不需要的模块、重置构建时间戳、注册 xmldoclet；再打
   aarch64 ELF、dark mode、跳过 Java 版本检查等补丁；
2. **依赖 FOD**：jmulticard 和 clienteafirma-external 各自跑
   `mvn install` + `dependency:go-offline`，把 `.m2/repository`
   做成 recursive fixed-output derivation，hash 记在
   `fixed-output-derivations.lock`；主包离线复用这些仓库再编译，
   保证可复现且不依赖网络；
3. **运行时**：`buildFHSEnv` 包 JRE，desktop item + wrapper；
   `autofirma-truststore` 从官方 PAe 来源的 `providers.json` +
   `CAs-by-provider/<CIF>.json` 生成 Java truststore；
   Firefox 集成写 `AutoFirma.js` prefs 和证书策略，systemd oneshot
   生成浏览器通信证书；HM 模块支持按 profile 启用，把 Java
   preferences 转成 XML prefs。

## 4. CI：上游监控 + 数据自动更新

workflow 设计非常完整：

- `monitor-upstream-releases.yml`：每天用 urlwatch 盯官方下载页和
  上游 GitHub tags/branches，变化时自动开 issue（带 `upstream` /
  `update` 标签）；
- `update-autofirma-trusted-providers.yml`：每周二/四/六抓官方
  可信服务商清单，自动开 PR（security 标签）；
- `update-autofirma-CAs-by-provider.yml`：每周一/三/五按
  `CAs_fetch_links.json` 矩阵下载各机构 CA，产出 artifact/PR；
- `update-fixed-output-derivations-lock.yml`：flake.lock 变化后重算
  全部 Maven 依赖 FOD hash 并开 PR；
- `docs.yml` 构建 mdbook 并部署 Pages；stale/labeler/dependabot
  常规化；
- Mergify 对 lock 文件类 PR 自动排队，等 `buildbot/nix-build`
  绿后 squash 合并。

## 5. 对我们仓库的启发

- 我们不涉及西班牙政务签名，不需要引入；
- 这是“Java/Maven 应用进 Nix”的完整范本：pom 批量改写 + Maven
  依赖缓存做成 FOD + FHS 环境 + 证书/浏览器集成；
- “urlwatch 盯官方页面 → 自动 issue → 自动 PR → buildbot 绿后
  Mergify 合并”的上游跟进链路，比我们的 nvfetcher 更新更偏
  “人工审核上游变化”，值得作为 zhyi-packages 或文档类仓库的
  运维参考。

## 6. 参考

- [autofirma-nix](https://github.com/nix-community/autofirma-nix)
- [文档站点](https://nix-community.github.io/autofirma-nix/)
