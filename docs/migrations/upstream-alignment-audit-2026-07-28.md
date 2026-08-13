# 2026-07-28 上游对齐偏差审计

## 结论

本次使用标准 fork 合并方式把 `upstream/master` 合入当前分支：

- 合并提交：`f5929283`
- 合并后适配提交：`09ab3a79`
- 对齐基准：`upstream/master`
- 当前分支：`agent/nanopi-r5c`

合并没有把仓库变成作者配置的逐文件副本。主机、域名、私有服务拓扑和硬件仍然
属于复刻环境，必须保留本地差异；通用模块、上游服务迁移和 nixpkgs 兼容方式则
尽量跟随作者。

以提交 `09ab3a79` 为审计点，当前分支相对 `upstream/master` 共涉及 **407 个
文件**：新增 93 个、删除 94 个、修改 210 个、重命名 10 个，共增加 30,573
行、删除 7,261 行。这是 fork 长期累计差异，不是本次合并新制造的 407 项偏差。
其中 `nixos/` 190 个文件、`hosts/` 125 个文件、`docs/` 34 个文件、`dns/`
22 个文件，是差异的主要来源。

本次专门用于合并后适配的 `09ab3a79` 只改了 **20 个文件**，增加 125 行、删除
982 行。大部分删除是为了跟随作者移除旧实现，不应计为新的功能偏离。

## Homepage 是否同步

已同步。Homepage 的服务卡片位于私有 `nixos-secrets` 仓库，不在主仓库：

- secrets 提交：`04dddb2 librechat: migrate secrets from Open WebUI`
- `homepage-dashboard-config.nix`：卡片名称改为 `LibreChat`
- 入口与健康检查：`https://ai.zhyi.xin`
- 图标：改用 `mdi-robot-outline`
- 删除 `homepage-dashboard-icons/open-webui.svg`
- 删除 `open-webui.yaml`
- 新增 SOPS 加密的 `librechat.yaml`
- Dex secret 从 Open WebUI client 切换到 LibreChat client

主仓库的 `flake.lock` 已锁定上述 secrets 提交，因此部署 `ml-home-vm` 后 Homepage
会加载新卡片；部署 `greencloud` 后 LibreChat 服务及入口才会实际可用。

## 本次合并中仍保留的有意偏差

按“偏离原因”归并，共有 **5 类有意偏差**。它们是复刻所需的适配边界，而不是
遗漏上游修改。

### 1. 主机清单与主机身份

不恢复作者已删除或本地不存在的主机，也不把本地主机改回作者的名称、地址和
硬件。当前继续使用 `cnvm`、`hostdare`、`ml-home-vm`、`google`、`router`、
`ml-builder`、`opi5p` 等本地主机。

本次把 5 个本地 `host.nix` 的 DN42 region 从裸数字改成作者的新命名常量：

- `cnvm`、`hostdare`、`ml-home-vm`、`google`：`Asia-E`
- `greencloud`：`Asia-SE`

这属于接口对齐；主机本身及其实际地域仍是 fork 差异。

### 2. 域名与 DNS 数据

不恢复作者的 `lantian.*`、`xuyh0120.*` 等域名，也不删除本地的 `zhyi.xin`、
`zhyi.cc`、`moliy.site` 和对应 DNS 记录。DNS 框架继续跟随上游，域名数据保持
本地所有权。

因此 `bitwarden.zhyi.xin`、`ai.zhyi.xin` 等名称不会因上游合并被换回作者域名。

### 3. LibreChat 的部署拓扑

作者的 LibreChat 模块默认同时导入本机 UniAPI，并访问
`http://uni-api.localhost/v1`。本 fork 的既定架构是：

```text
LibreChat (greencloud)
    -> https://uni-api.ml-home-vm.zhyi.cc/v1
    -> Provider
```

所以 `nixos/optional-apps/librechat.nix` 有 3 处必要适配：

1. 导入私有 `uni-api/` Provider 注册表，而不在 `greencloud` 再启动一个 UniAPI。
2. `baseURL` 指向 `ml-home-vm` 上的 UniAPI。
3. 使用 `zhyi.xin` 对应证书，因为公开入口是 `ai.zhyi.xin`。

这是本次最明确的运行架构偏差。它遵守仓库既有约束：UniAPI 是唯一 Provider
汇聚点，不能形成网关反向嵌套或请求环路。

### 4. greencloud 的服务组合

`hosts/greencloud/configuration.nix` 按作者迁移方向用 LibreChat 替换 Open
WebUI，但保留显式 `nginx-api.nix` 导入。原因是旧 Open WebUI 模块曾间接带入
该能力；移除旧模块后需要显式保留本地主机依赖。

### 5. 私有 secrets 与 Homepage 展示

作者 secrets 不可能直接复用。本 fork 自行维护：

- LibreChat 会话、JWT、OIDC 和 UniAPI 凭据；
- Dex 的 LibreChat client secret；
- Homepage 的 LibreChat 卡片；
- 本地 UniAPI Provider 注册表。

这些文件均留在私有 secrets 仓库，并由 SOPS 加密。它们是身份与凭据层面的必然
偏差。

## 已跟随作者移除或替换的内容

以下内容在本次适配中被删除或替换，目的是减少偏差：

- Open WebUI 模块、模型配置和 overlay；
- Dex 的 Open WebUI client；
- MCPO；
- Niri/DMS/Angrr 的残留模块、包和 flake lock 节点；
- 已被作者重构取代的单文件 Asterisk dialplan；
- 已进入 nixpkgs 上游、无法继续应用的 MPTCP 补丁；
- 旧 `services.mptcpd` 写法，改用当前上游 `settings` 接口。

`09ab3a79` 的 982 行删除主要来自这些清理，而非删除本地 hosts 或 domains。

## 未作为当前配置处理的历史文字

以下历史迁移文档仍可能出现 “Open WebUI”：

- `docs/migrations/greencloud-sg-migration.md`
- `docs/migrations/ml-home-vm-virtiofs-pve-migration.md`

它们描述迁移当时的旧系统，不代表当前服务拓扑，因此未机械替换。当前架构以
`docs/infrastructure/ai-api-gateway-chain.md` 为准。

## 验证结果

- `cnvm` 配置 dry-run 求值成功，Vaultwarden 为 `1.37.0`，Web Vault 为
  `2026.6.4+0`。
- `greencloud` 配置 dry-run 求值成功，LibreChat 已启用。
- 两次远程检查均以退出码 0 完成。
- NCPS 返回过已清理 narinfo 的 HTTP 500，公共缓存也出现连接重置；这是缓存基础
  设施问题，没有造成模块求值失败。
- NetBox 的 `apiTokenPeppersFile` 以及部分 systemd-networkd `routeConfig` 写法有
  弃用警告，后续可单独对齐，不影响本次合并结论。

## 后续同步规则

后续继续以合并 `upstream/master` 为主，不对 `hosts/` 和 `dns/domains/` 做
机械覆盖。解决冲突时按以下顺序判断：

1. 通用模块接口、包版本、弃用项和删除项优先跟随作者。
2. 主机名称、硬件、IP、域名、证书与 secrets 保持本地值。
3. 服务替换跟随作者，但必须按本地跨主机拓扑适配。
4. 每次合并后分别 dry-run 实际承载服务的目标主机。
5. 若保留新的架构偏差，应补充本文件，而不是只在提交信息里说明。
