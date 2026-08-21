# 域名与服务编排

> 2026-08-20 决策：**单一主域名 `zhyi.xin`**，`zhyi.cc` / `moliy.site` 全部并入。
> 代码树（vhost/DNS/证书）只出现 `zhyi.xin`；文档不再提旧双域。

## 1. 域名结构

单一 `zhyi.xin` 承担三层职责：

| 用途 | 模式 | 示例 |
| --- | --- | --- |
| 公开服务（面向用户、身份、协作） | `<svc>.zhyi.xin` | `git.zhyi.xin`、`dashboard.zhyi.xin`、`ai.zhyi.xin` |
| 主机地址记录 | `<host>.zhyi.xin` | `ml-builder.zhyi.xin`、`tencent.zhyi.xin` |
| 主机私有服务（`accessibleBy = "private"`） | `<svc>.<host>.zhyi.xin` | `metapi.tencent.zhyi.xin`、`hub.tencent.zhyi.xin` |

保留特殊层级域：`zhyi.dn42` / `zhyi.neo`（DN42 / NeoNetwork 层级域，非 Web 域名）。

## 2. 入口路径

- **公开服务** CNAME 到实际承载主机；服务在承载机本机 Nginx 直接提供；服务在
  家庭主机（rock5c/opi5p）时由入口机保留 Host/SNI 反向代理。
- **身份服务**（Dex/Pocket ID/Vaultwarden）由 volcengine 直接承载，DNS 直指
  `volcengine.zhyi.xin`。
- **家庭入站** 443 被运营商封锁时，外部入口统一 8443，由 Router 转换到 OPI5P
  Nginx 标准 443（Hairpin NAT 模式，不用全局 DNS 覆盖）。
- Attic 是例外：`attic.zhyi.xin` → volcengine 本机；`vaults3.zhyi.xin` 指向家庭
  DDNS 的 S3 存储后端。

## 3. 内网服务域名规范（新增私有服务必读）

任何新增内网服务（`accessibleBy = "private"`）都按本节操作，避免各自发明域名。

### 域名模式

`<service>.<hostname>.zhyi.xin`。**不要**用 `ltnet.zhyi.xin` 子域做服务域名：
`ltnet.zhyi.xin` 是主机地址记录域（`<host>.ltnet.zhyi.xin`），且通配证书不覆盖
`<svc>.ltnet.zhyi.xin` 二级子域。

### 解析：不需要显式 DNS 记录

`dns/common/host-recs.nix` 的 `hostRecs.Normal` 为每个主机生成
`*.<hostname>.zhyi.xin CNAME <hostname>.zhyi.xin` 通配记录，任何
`<svc>.<hostname>.zhyi.xin` 自动解析到主机地址（有公网 IP 的解析到公网 IP）。
公网解析到公网 IP 无妨：vhost 层 `accessibleBy = "private"` 拒绝非保留源地址。
**不要**为内网服务添加显式 CNAME/A 记录。

### 证书：使用现成的 `*.<hostname>.zhyi.xin` 通配

`nixos/optional-apps/acme/base-domains.nix` 的 `hostSubdomains` 为有 ZeroTier 的
主机签发 `*.<hostname>.zhyi.xin` 通配证书（`lets-encrypt-<hostname>.zhyi.xin`），
经 greencloud 签发并同步到所有主机。vhost 直接写：

```nix
sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
```

**不要**为单个服务申请新证书。

### vhost：定义在服务模块内

vhost 写在服务自身的 optional-apps 模块内，用 `${config.networking.hostName}`
派生域名，不写死主机名：

```nix
lantian.nginxVhosts."<svc>.${config.networking.hostName}.zhyi.xin" = {
  locations."/" = {
    proxyPass = "http://127.0.0.1:${LT.portStr.<Svc>}";
    proxyNoTimeout = true;   # 大文件/流式传输时保持
  };
  accessibleBy = "private";
  sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
  noIndex.enable = true;
};
```

### 家庭侧访问：hosts 覆盖到 LTNET 地址

家庭边缘（rock5c `hosts/rock5c/home-lan-edge.nix`）通过 hosts 文件把 tencent 等
主机上的服务解析到隧道地址（源地址是保留段，被 vhost 放行）：

```nix
networking.hosts."${LT.hosts.tencent.ltnet.IPv4}" = [
  "hub.tencent.zhyi.xin"
  "metapi.tencent.zhyi.xin"
];
```

其他主机访问时同样需要把域名覆盖到对应主机的 `ltnet.IPv4`（ZeroTier/LTNET）。

### 镜像加速服务的特殊限制

hubproxy（`hub.tencent.zhyi.xin`）容器镜像加速：

- **docker.io**：podman mirror `location = "hub.tencent.zhyi.xin"`（daocloud 兜底）。
- **gcr/quay/registry.k8s.io**：显式 `hub.tencent.zhyi.xin/<registry>/<image>`
  （hubproxy 按 `/v2/<registry>/` 前缀路由）；podman mirror 机制无法表达前缀路由，
  不要给这些 registry 配 mirror。
- **ghcr.io**：GitHub 拒绝数据中心 IP 匿名拉取，且 hubproxy 暂无凭据配置，不可用。

### 新增内网服务清单

1. 模块内定义服务 + vhost（`<svc>.${hostName}.zhyi.xin`，private）。
2. 端口登记 `helpers/constants/ports.nix`。
3. 确认 `*.<hostname>.zhyi.xin` 通配证书存在（greencloud `/nix/sync-servers/acme/`）。
4. 家庭侧访问路径在 `hosts/rock5c/home-lan-edge.nix` hosts 列表补充。
5. 无 DNS 记录改动。
6. `nix flake check` / colmena build 验证，按 [构建与部署](deployment.md) 部署。

## 4. 维护约束

- 先在作者原版确认服务是独立公开域名还是主机子域名，再决定当前名称；不能只凭
  服务用途猜测公开性。
- 作者的独立公开用户应用使用 `<service>.zhyi.xin`，并在入口承载机声明实际
  承载机；作者的主机私有服务使用 `<service>.<host>.zhyi.xin`。
- `helpers/constants/public-sites.nix`、vhost 的 `accessibleBy`/认证设置与 DNS
  必须一起审计。Gitea 等带自身认证的服务仍然是公开服务，不能仅因需要登录就改成
  主机私有域名。
- SSH、Colmena、LTNET 与 DDNS 使用的主机名必须保持直接地址记录，不能套用 Web
  服务通配符入口。
- 不再新增 `lantian.pub`、`xuyh0120.win`、`ltn.pw`、`zhyi.cc`、`moliy.site`
  入口；遗留引用按服务启用状态分批替换，涉及 OAuth、Matrix、邮件或应用回调
  URL 时必须连同服务配置一起改。
- DNS 修改与入口机 SNI 修改必须同一批发布，避免 CNAME 已切换但后端未分发。
