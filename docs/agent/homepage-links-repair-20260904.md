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

状态图例：⬜ 待诊断 / 🔍 诊断中 / ⏸️ 搁置（写明原因）/ ✅ 已修复已验证

| # | 组 | 链接 | 现象（2026-09-04） | 状态 | 根因 | 修复 | 验证 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | 超时 | lab.ml-2700.zhyi.xin | 连接超时（198.18.0.113） | ⬜ | | | |
| A2 | 超时 | syncthing.ml-2700.zhyi.xin | 连接超时（198.18.0.113） | ⬜ | | | |
| A3 | 超时 | volume.ml-2700.zhyi.xin | 连接超时（198.18.0.113） | ⬜ | | | |
| A4 | 超时 | lab.lubancat1.zhyi.xin | 连接超时（198.18.0.124） | ⬜ | | | |
| B1 | DNS | filebox.zhyi.xin | NXDOMAIN | ⬜ | | | |
| B2 | DNS | index.zhyi.xin | NXDOMAIN | ⬜ | | | |
| B3 | DNS | index-helper.zhyi.xin | NXDOMAIN | ⬜ | | | |
| B4 | DNS | searx.zhyi.xin | NXDOMAIN | ⬜ | | | |
| C1 | 证书 | matrix-federation.zhyi.xin | 证书 CN=snakeoil.local | ⬜ | | | |
| C2 | 证书 | vaults3.zhyi.xin | 证书 CN=snakeoil.local | ⬜ | | | |
| C3 | 证书 | linkr.opi5p.zhyi.xin | 证书 CN=zhyi.xin，域名不匹配 | ⬜ | | | |
| D1 | H2reset | lab.google.zhyi.xin | TLS 有效（ZeroSSL），HTTP/2 PROTOCOL_ERROR | ⬜ | | | |
| D2 | H2reset | lab.greencloud-jp.zhyi.xin | 同上 | ⬜ | | | |
| D3 | H2reset | lab.greencloud.zhyi.xin | 同上 | ⬜ | | | |
| D4 | H2reset | lab.hostdare.zhyi.xin | 同上 | ⬜ | | | |
| D5 | H2reset | lab.tencent.zhyi.xin | 同上 | ⬜ | | | |
| D6 | H2reset | lab.volcengine.zhyi.xin | 同上 | ⬜ | | | |
| D7 | H2reset | uni-api.greencloud.zhyi.xin | 同上（证书 CN=greencloud.zhyi.xin） | ⬜ | | | |
| D8 | H2reset | uni-api.hostdare.zhyi.xin | 同上（证书 CN=hostdare.zhyi.xin） | ⬜ | | | |
| E1 | 502 | hydra.zhyi.xin | 502 稳定 | ⬜ | | | |
| E2 | 502 | bazarr.rock5c.zhyi.xin | 502 稳定 | ⬜ | | | |
| E3 | 502 | prowlarr.rock5c.zhyi.xin | 502 稳定 | ⬜ | | | |
| E4 | 502 | radarr.rock5c.zhyi.xin | 502 稳定 | ⬜ | | | |
| E5 | 502 | sonarr.rock5c.zhyi.xin | 502 稳定 | ⬜ | | | |
| F1 | 翻转 | jellyfin-backend.opi5p.zhyi.xin | 首轮 301+有效证书 → 后持续 snakeoil | ⬜ | | | |
| F2 | 翻转 | handbrake-backend.opi5p.zhyi.xin | 同上 | ⬜ | | | |
| F3 | 翻转 | jellyfin-api.rock5c.zhyi.xin | 502 ↔ snakeoil 抖动 | ⬜ | | | |
| G1 | 循环 | lab.zhyi.xin | 307 自重定向无限循环 | ⬜ | | | |
| H1 | 403 | ai-api.zhyi.xin | 403 稳定（待判读是否预期） | ⬜ | | | |
| H2 | 403 | api.zhyi.xin | 403 稳定（同上） | ⬜ | | | |
| H3 | 403 | gemini.zhyi.xin | 403 稳定（同上） | ⬜ | | | |
| H4 | 403 | lemmy.zhyi.xin | 403 稳定（同上） | ⬜ | | | |
| H5 | 403 | s3.zhyi.xin | 403 稳定（同上） | ⬜ | | | |
| I1 | 404 | lab.dragon-q8b.zhyi.xin | 404（vhost 存活） | ⬜ | | | |
| I2 | 404 | lab.ml-builder.zhyi.xin | 404 | ⬜ | | | |
| I3 | 404 | lab.ml-laptop.zhyi.xin | 404 | ⬜ | | | |
| I4 | 404 | lab.opi5p.zhyi.xin | 404 | ⬜ | | | |
| I5 | 404 | lab.rock5c.zhyi.xin | 404 | ⬜ | | | |
| J1 | 注意 | letsencrypt-test-ssl.zhyi.xin | LE STAGING 测试证书，验证不过（预期内，确认后可关闭） | ⬜ | | | |

> 组提示：A=超时、B=DNS、C=证书、D=H2reset、E=502、F=状态翻转、G=重定向循环、
> H=403 待判读、I=404 待判读、J=预期内注意项。
> 诊断提示（轮 1 观察，供下轮参考）：ml-2700 与 lubancat1 整机 443 不可达但 mesh IP 可路由（待确认主机是否开机）；
> rock5c 502 组对应上游容器（\*arr 栈）；F 组两台后端 vhost 首轮正常说明配置曾生效，翻转发生在此轮检查期间。

## 进展日志

### 轮 1 · 2026-09-04 · 全量检查（完成）

- 从 `http://homepage.localhost/` 提取 105 个链接，批量探测（DNS + TLS + HTTP 状态），
  异常项复测 2 次，3xx 跟踪终态，TLS 异常项采集证书 subject/issuer
- 结论：66 正常 / 11 注意 / 28 异常，明细见上表；原始探测数据当时存于
  ml-laptop `/tmp/homepage_results.txt`（临时文件，不保证留存）
- 本轮仅检查，未做任何修复与诊断（用户要求）
- 检查环境：ml-laptop / 198.18.0.118 / 公网出口 115.215.10.72（大陆）
