# Homepage 链接修复计划（2026-09-04 启动）

> 背景：`homepage.localhost` 的链接列表由 flake 内所有主机的 `lantian.nginxVhosts`
> 自动生成，**反映仓库配置而非线上部署状态**。2026-09-04 完成第一轮全量可用性检查：
> 105 个链接 = 66 正常 + 11 注意 + 28 异常。
>
> **本文档是多轮修复的进度主记录**：每轮工作开始前先读「修复流程」和「状态追踪表」，
> 结束后必须更新状态列并追加「进展日志」，防止跨会话遗忘。

## 修复流程（每轮循环）

1. **诊断**：对目标项收集证据（本机 curl 复测、目标机 `journalctl -u nginx`、
   `nginx -T` 看实际 vhost、Prometheus blackbox 指标），只记录根因结论，不改动配置
2. **方案**：涉及取舍 / 停用服务 / 迁移的，先给方案 + 影响面，用户确认后动手（工作规范 #9）
3. **修复**：最小改动；公共模块 `nixos/optional-apps/*.nix`、`flake-modules/` 不擅改，
   需要行为差异用主机级覆盖或独立模块（工作规范 #4）；改完立即提交 + 对齐三方（工作规范 #1）
4. **验证**：用「检查方法」的命令重跑目标项，确认状态码达到预期
5. **记账**：更新本文档状态列 + 追加进展日志；若涉及域名 / 服务入口变更，
   同步对账 `domain-service-layout.md` / `fleet-service-chain.md` / `reference.md`（工作规范 #2）

## 检查方法（可复现）

检查环境：ml-laptop（198.18.0.118，LTNET 内），无代理，公网出口 115.215.10.72（大陆 IP）。
结果依赖出口位置，**跨出口复测时注意 403 口径**（见下）。

```bash
# 1. 取链接列表（105 个）
curl -s http://homepage.localhost/ | grep -oP 'href="\K[^"]+' | sort

# 2. 批量探测：DNS 解析 + TLS + HTTP 状态（连接 6s / 总 20s 超时）
curl -sS -o /dev/null --connect-timeout 6 --max-time 20 -w '%{http_code}|%{remote_ip}|%{ssl_verify_result}' <url>

# 3. 异常项复测 2 次排除偶发；3xx 用 -L 跟到终态
curl -sSL -o /dev/null --connect-timeout 6 --max-time 30 -w '%{http_code}' <url>

# 4. TLS 异常项看证书
openssl s_client -connect <host>:443 -servername <host> </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
```

## 判定口径

| 观测 | 判定 | 备注 |
| --- | --- | --- |
| 200 / 3xx→200 / 401（Basic 认证页） | ✅ 正常 | |
| 403 | ⚠️ 注意 | 站点侧访问控制拒绝（`blockMainlandChina` 或 `accessibleBy=private` 可能性）；本机公网出口为大陆 IP，是否预期需结合各 vhost 配置判读 |
| 404（有 HTTP 响应） | ⚠️ 注意 | vhost 存活但 `/` 无内容 |
| 证书 issuer 含 STAGING | ⚠️ 注意 | LE 测试证书，常规验证不通过属预期 |
| 连接超时 / DNS NXDOMAIN | ❌ 异常 | 复测 2 次仍复现才计入 |
| 证书 CN=snakeoil.local | ❌ 异常 | 默认证书；经验特征 = 该 SNI 无匹配 vhost，命中 `_default_https` 444 兜底 |
| 证书域名不匹配 | ❌ 异常 | 证书与 SNI 不对应 |
| TLS 成功但 HTTP/2 PROTOCOL_ERROR (curl exit 92) | ❌ 异常 | 444 兜底的另一特征（证书可为有效 wildcard） |
| 5xx | ❌ 异常 | 反代存活、上游故障 |
| 307/301 自我重定向循环 | ❌ 异常 | curl -L 终态仍是 3xx |

## 检查结果快照（2026-09-04，轮 1）

### 正常 66 个（本轮不动，仅记录）

直接 200（35）：homepage.localhost、syncthing.localhost、ai、attic、autoconfig、avatar、
bitwarden、bt.router、element、flapalerted、google-ssl、gopher、ha.opi5p、ha、hub.tencent、
id、immich、letsencrypt-ssl、login、memos、metacubexd.rock5c、metapi.tencent、
moviepilot.rock5c、n8n、nav、openspeedtest.rock5c、pb、peerbanhelper.dragon-q8b、qnap、
rsshub、stats、tools、um、whois、zerossl（均 .zhyi.xin）

重定向后 200（24）：alert、archivebox.dragon-q8b、asf、cal、dashboard、dsh、
frigate.opi5p、halo.volcengine、jellyfin、kvm.opi5p、lg、matrix-client、netbox、
prometheus.tencent、prometheus、rss、sub、syncthing.{greencloud-jp,ml-laptop,opi5p}、
wallos、git(303)、fastapi-dls.rock5c(307)、bitmagnet.dragon-q8b(301)

401 认证页（5）：books、dav、dav.opi5p、tachidesk、resilio.dragon-q8b(301→401)

偶发超时复测 200（2）：archiveteam.tencent、clawemail.tencent

### 状态追踪表

状态图例：⬜ 待诊断 / 🔍 诊断中 / ⏳ 方案待确认 / ⏸️ 搁置（写明原因）/ ✅ 已修复已验证

| # | 组 | 链接 | 现象（2026-09-04） | 状态 | 根因 | 修复 | 验证 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | 超时 | lab.ml-2700.zhyi.xin | 连接超时（198.18.0.113） | ⏸️ | 主机离线（见轮 2） | 开机即恢复 | 开机后复测 |
| A2 | 超时 | syncthing.ml-2700.zhyi.xin | 连接超时（198.18.0.113） | ⏸️ | 主机离线（见轮 2） | 开机即恢复 | 开机后复测 |
| A3 | 超时 | volume.ml-2700.zhyi.xin | 连接超时（198.18.0.113） | ⏸️ | 主机离线（见轮 2） | 开机即恢复 | 开机后复测 |
| A4 | 超时 | lab.lubancat1.zhyi.xin | 连接超时（198.18.0.124） | ⏸️ | 主机离线（见轮 2） | 开机即恢复 | 开机后复测 |
| B1 | DNS | filebox.zhyi.xin | NXDOMAIN | ✅ | 仓库早已退役 filecodebox（2cb1f5a2），首页是旧部署的陈旧快照 | 随轮 3 部署 ml-laptop 首页重生成，条目消失 | 首页已不含 |
| B2 | DNS | index.zhyi.xin | NXDOMAIN | ✅ | 同 B1（sun-panel 已从 dragon-q8b 移除 ff733028，模块成孤儿） | 同 B1 | 首页已不含 |
| B3 | DNS | index-helper.zhyi.xin | NXDOMAIN | ✅ | 同 B2 | 同 B2 | 首页已不含 |
| B4 | DNS | searx.zhyi.xin | NXDOMAIN | ✅ | 服务在 tencent（vhost 健康本机 200），LTNET 视图登记名 searx.tencent 与 vhost 名错位 | CNAME 改名 searx（轮 8，5be05741），CI 发布 | 轮 8 后验证：解析到 tencent.ltnet，200 |
| C1 | 证书 | matrix-federation.zhyi.xin | 证书 CN=snakeoil.local | ✅ | 配置正确：listenHTTPS.port=8448（Matrix federation 惯例端口），443 的 snakeoil 是设计使然 | 无需修复 | 轮 7：8448 返 404（federation 端点根路径正常行为） |
| C2 | 证书 | vaults3.zhyi.xin | 证书 CN=snakeoil.local | ✅ | 配置正确： opi5p 上的 8443 兼容端点（router DNAT），443 落在 rock5c 无此 vhost | 无需修复 | 轮 7：8443 返 403（S3 未签名请求正常拒绝） |
| C3 | 证书 | linkr.opi5p.zhyi.xin | 证书 CN=zhyi.xin，域名不匹配 | ✅ | 配置 bug：两级子域配了根域通配证书 zerossl-zhyi.xin | 改用机器通配 zerossl-opi5p.zhyi.xin（轮 7 一行修复，1024207bb） | 轮 7：证书验证通过，200 |
| D1 | H2reset | lab.google.zhyi.xin | TLS 有效（ZeroSSL），HTTP/2 PROTOCOL_ERROR | ✅ | 配置正确：private ACL 对公网源的 444 兑底（accessBlockAction）；mesh 源实测 404 正常放行 | 无需修复（mesh 内访问即正常） | 轮 8：mesh 源 404 |
| D2 | H2reset | lab.greencloud-jp.zhyi.xin | 同上 | ✅ | 同 D1（private ACL 拒公网源） | 无需修复 | 同 D1 |
| D3 | H2reset | lab.greencloud.zhyi.xin | 同上 | ✅ | 同 D1 | 无需修复 | 同 D1 |
| D4 | H2reset | lab.hostdare.zhyi.xin | 同上 | ✅ | 同 D1 | 无需修复 | 同 D1 |
| D5 | H2reset | lab.tencent.zhyi.xin | 同上 | ✅ | 同 D1 | 无需修复 | 同 D1 |
| D6 | H2reset | lab.volcengine.zhyi.xin | 同上 | ✅ | 同 D1 | 无需修复 | 同 D1 |
| D7 | H2reset | uni-api.greencloud.zhyi.xin | 同上（证书 CN=greencloud.zhyi.xin） | ✅ | 同 D1；mesh 源实测 403（应用鉴权，vhost 活着） | 无需修复 | 轮 8：mesh 源 403 |
| D8 | H2reset | uni-api.hostdare.zhyi.xin | 同上（证书 CN=hostdare.zhyi.xin） | ✅ | 同 D7 | 无需修复 | 同 D7 |
| E1 | 502 | hydra.zhyi.xin | 502 稳定 | ✅ | hydra 随 ml-builder 退役停用（import 被注释，13300 不监听），边缘 vhost 仍指 ml-builder | 迁至 ml-laptop 全新起（轮 3 确认） | 轮 3：边缘 200，UI 正常，管理员已建 |
| E2 | 502 | bazarr.rock5c.zhyi.xin | 502 稳定 | ✅ | 服务已被 MoviePilot 替代并有意停用（media-apps.nix enable=mkForce false），vhost 遗留 | 撤除 import 清死链（轮 3 确认） | 轮 3：vhost 已消失，首页不再列出 |
| E3 | 502 | prowlarr.rock5c.zhyi.xin | 502 稳定 | ✅ | 同 E2 | 同 E2 | 同 E2 |
| E4 | 502 | radarr.rock5c.zhyi.xin | 502 稳定 | ✅ | 同 E2 | 同 E2 | 同 E2 |
| E5 | 502 | sonarr.rock5c.zhyi.xin | 502 稳定 | ✅ | 同 E2 | 同 E2 | 同 E2 |
| F1 | 翻转 | jellyfin-backend.opi5p.zhyi.xin | 首轮 301+有效证书 → 后持续 snakeoil | ✅ | HTTP-only 内部回源 vhost（ml-home-vm 时代设计）在 rock5c，DNS 按名字解析到 opi5p → 默认服务器兑底 | 撤除死源 vhost（上游无跨机 -backend 惯例，全仓无消费者），轮 5 | 首页已不含，求值断言通过 |
| F2 | 翻转 | handbrake-backend.opi5p.zhyi.xin | 同上 | ✅ | 同 F1（handbrake-rockchip 同模式） | 同 F1，轮 5 | 首页已不含 |
| F3 | 翻转 | jellyfin-api.rock5c.zhyi.xin | 502 ↔ snakeoil 抖动 | ✅ | HTTP-only（设计如此）；https 直连必 snakeoil；HTTP 80 的 502 = 上游 macmini 关机 | jellyfin 定格 rock5c，回源改本机 unix socket，轮 5 | 轮 5：HTTP 80 返 302，重写路径 401（已达 Jellyfin） |
| G1 | 循环 | lab.zhyi.xin | 307 自重定向无限循环 | ✅ | 域名合并 artifact：上游 lab.xuyh0120.win→lab.lantian.pub 跨域重定向，单域化后退化为自跳（vhosts.nix 硬写） | 删自跳块；舰队无 lab 站，条目随首页退役（nginx-lab 模块保留待用） | 轮 8：307 消失，首页 96→95 |
| H1 | 403 | ai-api.zhyi.xin | 403 稳定（待判读是否预期） | ✅ | 应用层鉴权拒绝（非 nginx ACL），配置正确 | 无需修复 | 轮 8 判读结案 |
| H2 | 403 | api.zhyi.xin | 403 稳定（同上） | ✅ | 同 H1 | 无需修复 | 同 H1 |
| H3 | 403 | gemini.zhyi.xin | 403 稳定（同上） | ✅ | 同 H1 | 无需修复 | 同 H1 |
| H4 | 403 | lemmy.zhyi.xin | 403 稳定（同上） | ✅ | 同 H1 | 无需修复 | 同 H1 |
| H5 | 403 | s3.zhyi.xin | 403 稳定（同上） | ✅ | s3 返 S3 标准 AccessDenied XML（缺 Authorization 头），应用层行为 | 无需修复 | 轮 8 判读结案 |
| I1 | 404 | lab.dragon-q8b.zhyi.xin | 404（vhost 存活） | ✅ | /var/www/lab.<host> 空目录，autoindex 404，vhost 本身正常 | 无需修复（放文件即有列表） | 轮 8 判读结案 |
| I2 | 404 | lab.ml-builder.zhyi.xin | 404 | ✅ | 同 I1 | 无需修复 | 同 I1 |
| I3 | 404 | lab.ml-laptop.zhyi.xin | 404 | ✅ | 同 I1 | 无需修复 | 同 I1 |
| I4 | 404 | lab.opi5p.zhyi.xin | 404 | ✅ | 同 I1 | 无需修复 | 同 I1 |
| I5 | 404 | lab.rock5c.zhyi.xin | 404 | ✅ | 同 I1 | 无需修复 | 同 I1 |
| J1 | 注意 | letsencrypt-test-ssl.zhyi.xin | LE STAGING 测试证书，验证不过（预期内） | ✅ | 该 vhost 本就是证书链路测试用途，STAGING 证书属预期 | 无需修复 | 轮 8 确认结案 |

> 组提示：A=超时、B=DNS、C=证书、D=H2reset、E=502、F=状态翻转、G=重定向循环、
> H=403 待判读、I=404 待判读、J=预期内注意项。
> 诊断提示（轮 1 观察，供下轮参考）：ml-2700 与 lubancat1 整机 443 不可达但 mesh IP 可路由（待确认主机是否开机）；
> rock5c 502 组对应上游容器（\*arr 栈）；F 组两台后端 vhost 首轮正常说明配置曾生效，翻转发生在此轮检查期间。

## 进展日志（最新在上）

### 轮 8 · 2026-09-04 · D/G/I/H/B4/J 全部结案（完成 ✅）

- **D 组 ×8**：配置正确。lab.*/uni-api.* vhost 均为 `accessibleBy = "private"`，
  公网源访问被 ACL 兑底（accessBlockAction=/444.internal → HTTP/2 PROTOCOL_ERROR
  即 exit 92 签名）；mesh 源实测 lab.google 404、uni-api.greencloud 403（应用
  鉴权，vhost 活着）。无需修复，从 mesh/保留源访问即正常
- **G1 lab.zhyi.xin 307 自循环**：真配置 bug。上游 vhosts-lantian.nix 中
  lab.xuyh0120.win 307 跳 lab.lantian.pub（跨域到正牌 lab 站）；域名统一并入
  zhyi.xin 时机械替换使两目标同名，重定向退化为自跳，并与 nginx-lab 模块的
  完整 vhost 同名合并（return 短路 try_files）。修复：删 vhosts.nix 自跳块
  （bddc6d5a）；我舰队无主机部署 nginx-lab（exam 里是 terrahost），lab 站
  不存在，条目随首页退役（96→95），nginx-lab 模块保留待用
- **I 组 ×5**：配置正确。lab.<host> root 指向 /var/www/lab.<host>，空目录时
  autoindex 404，vhost 本身正常；放文件即有列表。结案无改动
- **H 组 ×5**：403 为应用层鉴权拒绝（s3 返 S3 标准 AccessDenied XML 等），
  非 nginx ACL，配置正确。结案无改动
- **B4 searx**：服务在 tencent 且健康（本机 200，accessibleBy=private），
  但 LTNET DNS 视图登记名 searx.tencent 与 vhost 名 searx.zhyi.xin 错位 →
  mesh 内 NXDOMAIN。修复：CNAME 改名 searx（5be05741，对齐 rsshub 一级名
  先例），已推 CI 发布，TTL 1h 内生效待复测
- **J1**：LE STAGING 测试证书属预期，确认结案

**当前进度**：105 → 95 链接；已解决/结案 35 项，仅剩 A1-A4（等待开机，物理动作）。
B4 复测确认：searx.zhyi.xin 解析到 tencent.ltnet 并返 200，全链路闭环。

已知遗留批次：opi5p 边缘残留（jellyfin/tachidesk 指向旧目标）两份 vhost、
prometheus scrape-configs.nix 的 exportarr 遗留目标（公共模块）。

**环境变更**：ml-builder 已关机（2026-09-04 晚，用户关机）；colmena 部署与
构建流程暂停，本机仓库已全部推送 origin（1c1c82f9），ml-builder 的
/nix/src/nixos-config 停在 5be05741（缺轮 8 文档提交），待其上线后补同步。

### 轮 7 · 2026-09-04 · C 组（证书 ×3）诊断+修复（完成 ✅）

按用户口径「没开机的不论，配置文件没问题就行」逐项核验：

- **C1 matrix-federation**：配置正确。listenHTTPS.port = Matrix.Public (8448)，
  federation 惯例端口；443 snakeoil 为默认服务器兑底属设计内。实测 8448 → 404
  （federation 端点根路径正常行为）。结案，无改动
- **C2 vaults3**：配置正确。 opi5p 上的 8443 兼容端点（router DNATs
  8443→opi5p:8443）；443 落在 rock5c（当前 DNAT 目标）无此 vhost。实测
  8443 → 403（S3 对未签名请求的正常拒绝）。结案，无改动
- **C3 linkr.opi5p**：配置 bug 已修。vhost 证书配了根域通配 zerossl-zhyi.xin，
  不覆盖两级子域 linkr.opi5p；改机器通配 zerossl-opi5p.zhyi.xin（syncthing
  模块 zerossl-${hostName} 同款）。commit 1024207bb，部署 opi5p 后证书验证
  通过、返 200（回源设备 192.168.0.42 在线）

### 轮 6 · 2026-09-04 · 跨机 -backend 模式全面退役（完成 ✅）

用户确认：跨机 -backend 可以没有；以最对齐 exam、最小改动方式收尾。
commit 46997540，仅改 media-edge.nix 一个文件，部署 rock5c。

- 上游对照：exam 有 tachidesk.nix，vhost 即 `tachidesk.xuyh0120.win`
  （带 basicAuth）跑在服务机上——我们的 tachidesk.nix 逐字对齐（换域名），
  零改动；坏的只是 rock5c 边缘指向 opi5p 的回源跳板（tachidesk 8-28 已迁
  dragon-q8b，实测 auth 过后 301 到无人定义的域名 → snakeoil 死循环）
- 实施：media-edge.nix 把 tachidesk.zhyi.xin / tachidesk.localhost 改用
  mkProxyLocation 直连 tachidesk.dragon-q8b.zhyi.xin（复用 backendHost 映射
  加 tachidesk=dragon-q8b），backendLocation 辅助函数删除
- 验证：边缘→dragon-q8b 链路 401（Server: zhyi/dragon-q8b，到达真身 vhost）；
  公网 401 正常；jellyfin 302 / jellyfin-api 302 未受影响
- **跨机 -backend 命名自本轮起全面退役**：新服务消费一律机器域 vhost
  （${service}.${hostName}.zhyi.xin）+ 边缘直连；同机容器消费走
  --add-host + HTTP-only vhost（jellyfin-api 模式，上游对应物 localhost 变体）

### 轮 5 · 2026-09-04 · F 组修复（完成 ✅）

用户决策：**jellyfin 定格 rock5c**；F1/F2 参照上游 exam 对齐。
commit 7f24015a，部署 rock5c + ml-laptop（首页重生成，105 → 96 链接）。

上游对照结论：exam 无跨机 -backend 惯例（上游 edge 与 media 同机 lt-home-vm，
完整 HTTPS vhost 直连本机 unix socket + jellyfin.localhost）；我们的
-backend.<host> 是 2026-08-01 自建 rockchip 模块时为 ml-home-vm 前沿设计的
回源名，前沿退役后全仓零消费者。

实施内容：
- jellyfin-rockchip.nix / handbrake-rockchip.nix：撤除两个 -backend vhost 块
- media-edge.nix：jellyfin-api.rock5c 回源 macmini:8096 → 本机 /run/jellyfin/socket
  （jellyfin 定格 rock5c，修 502；SelectableMediaFolders 重写保留）
- 求值断言：-backend 两名已消失，jellyfin/jellyfin-api 保留；部署后
  jellyfin-api HTTP 返 302、公网 jellyfin.zhyi.xin 302 未受影响

**遗留待决策**（未动）：opi5p media-center.nix 残留指向 macmini 的 jellyfin
vhost（远端 8443 入口），macmini 关机期间远端访问不可用；首页生成器对
HTTP-only vhost 一律生成为 https 链接的结构问题（后续此类回源名可考虑
localVhosts 或生成器标记）。已知噪音：ml-laptop 切换时 /etc/subuid|subgid
"Device or resource busy" 警告（不影响激活）。

### 轮 4 · 2026-09-04 · F 组诊断（完成）+ ml-builder tag 恢复

**ml-builder tag 恢复**（用户决定保留构建机角色）：commit 4a241af7，恢复 nix-builder tag
与 binfmt 普通赋值；ml-builder 本机 switch（colmena 自推无授权，改用
nix build + switch-to-configuration）；ml-laptop 重新部署后 hydra builder 列表
= ml-builder(x86) + opi5p(aarch64) + localhost。

**F 组诊断结论**（只诊断未改动，用户中跹确认 macmini 未开机）：

1. **macmini (192.168.0.54) 关机**——三台机 TCP/ICMP 全不可达，ARP incomplete。
   media-edge.nix 注释宣称 Jellyfin 已迁 macmini（VideoToolbox），但只迁了一半：
   MoviePilot 消费端 jellyfin-api 已指向 macmini（502），公网入口实际还在用
   rock5c 本机残留的旧 jellyfin 实例（active）
2. **公网 jellyfin.zhyi.xin 活着的真相**：响应头 Server: zhyi/rock5c + 延迟 3ms ——
   路由器 DNAT → rock5c nginx → rock5c 本机旧 jellyfin。与 media-edge 注释的
   macmini 目标拓扑矛盾，媒体链路处于「迁移半途」状态
3. **F1/F2 结构性死链**：jellyfin-backend/handbrake-backend.opi5p 是 HTTP-only
   私有回源 vhost（listenHTTPS=false，proxy 本机 unix socket），注释注明服务对象是
   已退役的 ml-home-vm 公网前沿；模块 import 在 rock5c（迁移后随服务走），但
   mesh DNS 按名字模式把 *.opi5p 解析到 opi5p —— opi5p 无此 vhost → snakeoil 444。
   首页生成器把 HTTP-only vhost 生成为 https 链接，此类回源名永远成死链
4. **F3**：jellyfin-api.rock5c 同为 HTTP-only（首页生成为 https → 000 结构性）；
   HTTP 80 的 502 = 上游 macmini 关机，开机后自愈
5. **风险提示（未处理）**： opi5p 残留的 jellyfin.zhyi.xin vhost 指向关机的 macmini；
   若 DNAT 切回 opi5p 或其配置重载生效，公网 jellyfin 将 502。 rock5c 旧 jellyfin
   实例与 macmini 官方目标并存，两套库一致性存疑。 op后待用户决策：
   jellyfin 最终落点（macmini vs rock5c）与 F1/F2/F3 的去留

### 轮 3 实施 · 2026-09-04 · E 组修复（完成 ✅）+ B1-B3 侧效结案

方案经用户确认后实施（E1 数据全新起；E2-E5 撤除前完成消费者调研）。
commit c3433d72，四台 toplevel 求值通过后部署：ml-laptop → greencloud → rock5c。

**E1 hydra 迁移落地**：
- ml-laptop：import hydra + nix-builder tag + aarch64-cross；hydra 全家桶启动，
  13300 监听，UI 200；管理员 zhyi 已建（随机密码已交用户，可重置）
- greencloud：vhost 改指 ml-laptop，hydra.zhyi.xin 边缘 200
- ml-builder：摘 nix-builder tag；binfmt 改 mkForce true 解决优先级冲突
  （摘 tag 后 environment.nix 标签表达式变 false，同 92bdd542 先例）
- 构建拓扑生效：ml-laptop machines-with-localhost = localhost（x86_64+QEMU 平台，4 jobs）
  + opi5p（aarch64 原生 8 jobs + big-parallel），ml-builder 已不在列表
- 部署备志：ml-laptop 是 manualDeploy 主机，ml-builder 需 ssh 覆盖才能推
  （198.18.0.118 + mac-book 钥匙）；greencloud 的 ssh 覆盖
  （203.55.176.158→198.18.0.120:2222）此前被清掉，本次已补回

**E2-E5 死链清理落地**：media-apps.nix 撤 sonarr/radarr/bazarr/prowlarr/decluttarr
五个 import，vhost/homepage 条目消失，直连变 444 兑底；moviepilot/jellyfin
200/302 未受影响；服务数据留在盘上，回滚 = git revert。

**B1-B3 侧效结案**：本次部署 ml-laptop（homepage 所在机）后首页从陈旧快照刷新为
当前 flake 口径，filebox/index/index-helper 三个早已在仓库中退役的条目随之消失
（105 → 98 个链接）。B4 searx 仍在列，待诊断。

**遗留（不在 E 组）**：prometheus scrape-configs.nix 的 rock5c exportarr 目标
（公共模块）待另批次清理；F 组状态翻转未动（下轮）。

### 轮 3 · 2026-09-04 · E 组（502 ×5）诊断（完成，方案待确认）

**E1 hydra.zhyi.xin**：greencloud 边缘 vhost（`hosts/greencloud/configuration.nix:131`）
`mkForce` 指向 ml-builder:13300，但 hydra 模块 import 已在 ml-builder 退役流程中被注释
（`hosts/ml-builder/configuration.nix:51`），远端 hydra inactive、13300 不监听 → 502。
本机 ml-laptop 未部署 hydra（服务 inactive，host 配置无引用）。

**E2-E5 \*arr 栈**：`hosts/rock5c/media-apps.nix` 注释明说这些服务已被 MoviePilot
完全替代（"must not run alongside the new chain"），`enable = mkForce false` 下单元以
`-disabled` 形式存在，但四个模块内定义的 nginx vhost 没跟着撤 → 502。

附带发现（不在 E 组修复范围）：`nixos/optional-apps/prometheus/scrape-configs.nix`
（公共模块）里 rock5c 四个 exportarr 抓取 job 现在必然 down，属同一次迁移的监控遗留。

### 轮 3 方案（待用户确认后实施）

**E1 迁移方案**（目标拓扑：hydra 在 ml-laptop，x86 构建本机，ARM 构建 opi5p）：
1. `hosts/ml-laptop/configuration.nix`：import `nixos/optional-apps/hydra`；
   加 `nix.settings.extra-system-features = [ "aarch64-cross" ]`（对齐 ml-builder:80，
   四个 ARM 硬件内核包的 requiredSystemFeatures 硬性要求）
2. `hosts/ml-laptop/host.nix`：加 `nix-builder` tag（kernel swappiness=0；binfmt 已由
   client tag 启用，无需重复）
3. `hosts/greencloud/configuration.nix:131` mkForce 目标 ml-builder → ml-laptop
4. 依赖无需额外准备：secrets 已覆盖（`.sops.yaml` 含 `&ml_laptop` recipient，
   hydra.yaml / common/attic.yaml 直接可解密）；opi5p 已带 `nix-builder` tag 通告
   native aarch64（nix-distributed 自动收录），ml-laptop 的 localhost 行由
   `machines-with-localhost` 生成，x86 构建走本机
5. **待决：数据迁移**——ml-builder 遗留 /var/lib/hydra 1.3G（构建日志+queue 状态）+
   PostgreSQL 97M（inactive 但数据完整）。(a) 全新起：零迁移，jobset 需重建；
   (b) 迁 DB：rsync /var/lib/postgresql + /var/lib/hydra，保留构建历史

**E2-E5 清理方案**：改 `hosts/rock5c/media-apps.nix`（host 文件，非公共模块）：
移除 sonarr/radarr/bazarr/prowlarr（+decluttarr）模块 import，同步清理
gatedServices / migratedServices 列表对应条目 → vhost 与 homepage 死链条目消失。
数据在 /nix/persistent/var/lib 不动，回滚 = git revert 重新加回 import。
监控侧 exportarr 遗留 job 单独批次处理（涉公共模块）。

### 轮 2 · 2026-09-04 · A 组（超时 ×4）诊断（完成）

结论：**根因 = 主机不在线**，四个嫌疑中排除三个——

- **被墙：排除**。目标 198.18.0.113 / .124 是 198.18.0.0/15 mesh 私网地址，
  流量不出 ZeroTier 隧道，公网墙无法介入
- **服务失败：排除**。ICMP、SSH(2222)、80/443 同时无响应；仅 nginx 服务挂掉
  不会带走 ping + ssh
- **配置问题：排除**。同批检查中其他主机的同模板 vhost（lab.ml-laptop 等）响应正常；
  且主机整机不可达与 vhost 配置无关
- **主机离线：证实**，四重独立证据：
  1. mesh IP ICMP 100% 丢包，TCP 2222/443/80 全部超时（自 ml-laptop）
  2. ZeroTier peer 表（ml-laptop `zerotier-cli peers`）中无 `214f8619a9`
     (ml-2700) 与 `fde3beab16` (lubancat1)，节点连 PLANET 中继路径都没有 = ZT 层离线
  3. 同家庭 LAN 侧（ml-laptop 与 ml-2700 同在 192.168.0.0/24）ICMP 全丢，
     192.168.0.53 ARP incomplete = L2 层就不在场
  4. Prometheus（tencent）：lubancat1 的 node/nginx/coredns/wireguard 四 job 全部
     up=0；ml-2700 无监控覆盖（client 机，符合预期）
- 旁证：2026-09-02 syncthing 集群调整时 ml-2700 就已处于关机状态，之后未开机
- **处置**：A1-A4 均为物理动作（开机），无法远程修复，挂起等主机上线后复测。
  注意 ml-2700 开机后除 vhost 恢复外，还欠 syncthing 集群三步操作
  （加 greencloud-jp 设备、更新 media 文件夹 devices、删 greencloud 旧设备），
  见 syncthing 拓扑备忘（2026-09-02）
- 本轮仅诊断，未改任何配置

### 轮 1 · 2026-09-04 · 全量检查（完成）

- 从 `http://homepage.localhost/` 提取 105 个链接，批量探测（DNS + TLS + HTTP 状态），
  异常项复测 2 次，3xx 跟踪终态，TLS 异常项采集证书 subject/issuer
- 结论：66 正常 / 11 注意 / 28 异常，明细见上表；原始探测数据当时存于
  ml-laptop `/tmp/homepage_results.txt`（临时文件，不保证留存）
- 本轮仅检查，未做任何修复与诊断（用户要求）
- 检查环境：ml-laptop / 198.18.0.118 / 公网出口 115.215.10.72（大陆）
