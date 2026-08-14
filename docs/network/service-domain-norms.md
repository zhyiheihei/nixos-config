# 内网服务域名规范（Service Domain Norms）

> 统一内网/私密服务的域名、证书、解析与暴露方式。任何新增内网服务
> （accessibleBy = "private" 的服务）都按本文操作，避免各自发明域名。

## 1. 域名模式

内网服务域名统一为 **`<service>.<hostname>.zhyi.cc`**，与公网服务同域但
通过 vhost 的 `accessibleBy = "private"` 限制访问源：

| 服务 | 运行主机 | 域名 | 示例 |
| --- | --- | --- | --- |
| metapi | tencent | `metapi.tencent.zhyi.cc` | 模块内 vhost |
| hubproxy | tencent | `hub.tencent.zhyi.cc` | 模块内 vhost |
| prometheus | tencent | `prometheus.tencent.zhyi.cc` | 主机配置 vhost |
| searxng | opi5p | `searx.opi5p.zhyi.cc` | 模块内 vhost |

**不要**使用 `ltnet.zhyi.cc` 子域做服务域名：`ltnet.zhyi.cc` 是主机地址
记录域（`<host>.ltnet.zhyi.cc`），且 `*.zhyi.cc` 通配证书不覆盖
`<svc>.ltnet.zhyi.cc` 这类二级子域。

## 2. 解析：不需要显式 DNS 记录

`dns/common/host-recs.nix` 的 `hostRecs.Normal` 为每个主机生成
`*.<hostname>.zhyi.cc CNAME <hostname>.zhyi.cc` 通配记录，因此任何
`<svc>.<hostname>.zhyi.cc` 自动解析到主机地址（有公网 IP 的主机解析到
公网 IP）。

- 公网解析到公网 IP 无妨：vhost 层的 `accessibleBy = "private"` 会拒绝
  非保留源地址，公网用户无法使用（防偷流量）。
- **不要**为内网服务添加显式 CNAME/A 记录（通配已覆盖，加了反而需要
  维护和删除）。

## 3. 证书：使用现成的 `*.<hostname>.zhyi.cc` 通配

`nixos/optional-apps/acme/base-domains.nix` 的 `hostSubdomains` 为所有
有 ZeroTier 的主机签发 `*.<hostname>.zhyi.cc` 通配证书
（`lets-encrypt-<hostname>.zhyi.cc`），经 greencloud 签发并同步到所有
主机（`/nix/sync-servers/acme/`）。

- vhost 直接写 `sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";`
- **不要**为单个服务申请新证书。

## 4. vhost：定义在服务模块内

与 `metapi.nix`、`searxng.nix` 一致，vhost 写在服务自身的 optional-apps
模块内，用 `${config.networking.hostName}` 派生域名，不写死主机名：

```nix
lantian.nginxVhosts."<svc>.${config.networking.hostName}.zhyi.cc" = {
  locations."/" = {
    proxyPass = "http://127.0.0.1:${LT.portStr.<Svc>}";
    proxyNoTimeout = true;   # 大文件/流式传输时保持
  };

  accessibleBy = "private";
  sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
  noIndex.enable = true;
};
```

## 5. 家庭侧访问：hosts 覆盖到 LTNET 地址

家庭边缘（rock5c `hosts/rock5c/home-lan-edge.nix`）通过 hosts 文件把
tencent 上的服务解析到隧道地址（源地址因此是保留段，被 vhost 放行）：

```nix
networking.hosts."${LT.hosts.tencent.ltnet.IPv4}" = [
  "hub.tencent.zhyi.cc"
  "metapi.tencent.zhyi.cc"
];
```

其他主机访问 tencent 服务时同样需要把域名覆盖到 `LT.hosts.tencent.ltnet.IPv4`
（198.18.0.128，ZeroTier/LTNET）。

## 6. 镜像加速服务的特殊限制

hubproxy（`hub.tencent.zhyi.cc`）的容器镜像加速注意：

- **docker.io**：podman mirror 配置
  `[[registry.mirror]] location = "hub.tencent.zhyi.cc"`（daocloud 保留作
  兜底）。
- **gcr/quay/registry.k8s.io**：显式拉取
  `hub.tencent.zhyi.cc/<registry>/<image>`（hubproxy 按 `/v2/<registry>/`
  前缀路由）。podman 的 mirror 机制只会替换 registry 主机并在其后追加
  `/v2/`，**无法**表达 hubproxy 的前缀路由，不要给这些 registry 配 mirror。
- **ghcr.io**：GitHub 拒绝数据中心 IP 的匿名拉取（token DENIED），且
  hubproxy 暂不支持凭据配置，当前不可用。

## 7. 新增内网服务清单

1. 模块内定义服务 + vhost（域名 `<svc>.${hostName}.zhyi.cc`，private）。
2. 端口登记 `helpers/constants/ports.nix`。
3. 确认 `*.<hostname>.zhyi.cc` 通配证书存在（greencloud
   `/nix/sync-servers/acme/lets-encrypt-<hostname>.zhyi.cc-rsa/`）。
4. 家庭侧访问路径在 `hosts/rock5c/home-lan-edge.nix` 的 hosts 列表补充。
5. 无 DNS 记录改动。
6. `nix flake check` / colmena build 验证，按 [构建与部署](../operations/deployment.md)
   部署。
