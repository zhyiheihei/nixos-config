# /etc/hosts 映射清理审计

> 2026-08-05。结论：停用公共自动生成 `/etc/hosts` 的模块，域名统一走自建
> DNS / 公共 DNS；各主机剩余显式 `networking.hosts` 均有功能性用途，评估后保留。

## 停用与删除

- `nixos/common-apps/nginx/hosts.nix`：**文件保留作者原版**（已逐字节核对
  `../nixos-config-exam`），但本复刻不再 import 它。该模块会把本机声明的所有
  vhost 名自动写进 `/etc/hosts`，是 `/etc/hosts` 大规模污染的唯一来源，且会让
  `zhyi.xin` 在 greencloud 上自映射到空静态目录，导致 Miniflux 无法订阅 Halo
  博客。
- `helpers/constants/domain-owners.nix` 及 `constants.nix` 中对应导出：该表只
  服务于上面的 hosts 生成器，且是复刻新增（作者没有），随生成器一并移除。

## 作者对齐核对

| 文件 | 与作者原版对比 | 结论 |
| --- | --- | --- |
| `nixos/common-apps/nginx/hosts.nix` | 已恢复，diff 为空 | 保留作者文件；仅本复刻不 import |
| `nixos/common-apps/nginx/default.nix` | 仅移除 `./hosts.nix` import | 有意偏离，注释于提交说明 |
| `helpers/constants.nix` | diff 为空 | 与作者一致 |
| `nixos/optional-apps/dex.nix` | 仅域名/复刻差异；作者 `actual` client 此前复刻已不用，本次只移除复刻新增的 freshrss/linkwarden | 未误删作者内容 |
| `helpers/constants/ports.nix` | 仅复刻新增端口常量 | 作者内容完整 |
| `miniflux.nix`、`rsshub.nix` | 仅复刻域名差异 | 作者内容完整 |
| `freshrss.nix`、`linkwarden.nix` | 作者没有，复刻新增 | 按用户要求保留文件、不 import |
| `domain-owners.nix` | 作者没有，复刻新增 | 已删除，无作者内容 |

## 各主机显式 `networking.hosts` 审计

| 主机/模块 | 映射 | 评估 |
| --- | --- | --- |
| `ml-2700` | 本机 hostname → 本机 LAN IP | 保留：为桌面机提供稳定的本机 LAN 自解析 |
| `pve-5700u` | 本机 hostname、`ml-builder.zhyi.cc` → LAN IP | 保留：`ml-builder.zhyi.cc` 没有 DNS 记录，删除会导致 builder 地址不可解析 |
| `rock5c` | greencloud 私有服务（axonhub/metapi/n8n-bridge/n8n/rsshub/openai-edge-tts）→ LTNET IP | 保留：部分无公网 DNS，且 `rsshub.zhyi.xin` 为 private vhost，必须从 LTNET 源地址访问 |
| `opi5p` | `vaults3.zhyi.xin` → 本机 LAN IP | 保留：DNS 指向 home-ddns（公网入口），LAN 直连可避免 NAT hairpin 依赖 |
| `open5gs` | 3GPP 内部测试域名 → 127.0.0.x | 保留：服务内部测试网络，不应走 DNS |
| `bird-lg-go` | `*.ltnet.zhyi.cc` → LTNET IP | 保留：BGP 路由查询的内部名称映射 |
| `gcp` | `metadata.google.internal` → 169.254.169.254 | 保留：云元数据固定地址 |

## 生效方式

公共生成器停用后，各主机在下次 `nixos-rebuild` / Colmena switch 时 `/etc/hosts`
会回到 NixOS 默认内容（localhost 等），不再出现成百条域名映射。域名解析统一由
公共 DNS 与 LTNET 自建 DNS 承担。`hosts.nix` 文件保留在仓库中，与作者原版一致，
仅本复刻的 `default.nix` 不 import 它。
