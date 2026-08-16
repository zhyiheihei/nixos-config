# 字幕源扩展调研（2026-08-16）

状态：调研完成，方案待用户决策后实施。本文只调研不改动配置。

## 背景

媒体链路字幕为双通道：

- **MoviePilot SubtitleAssistant 插件**（rock5c，事件触发式字幕补充）
- **ChineseSubFinder**（rock5c 容器，周期扫描媒体库补齐字幕）

2026-08-16 巡检发现 a4k 源完全失效、assrt 配额紧张、CSF 项目已停滞。
本文调研现有字幕源的可用性，评估可扩展的源并给出方案。

## 现状盘点（实机证据，2026-08-16）

### MoviePilot SubtitleAssistant（v3 内置插件，活跃维护）

插件源码位于容器内 `/app/app/plugins/subtitleassistant/`，支持三种源：

| 源 | 状态 | 说明 |
| --- | --- | --- |
| `moviepilot` | 启用 | 通过 MP 站点索引搜索 M-Team / PTTime 字幕区；当前两个站均返回 0 结果（2026-08-09 风险登记在案），属上游站点适配器限制 |
| `assrt` | 启用 | API Token 已配置；**免费 API 每日配额极小**（见下） |
| `opensubtitles` | **未启用** | 原生支持 api.opensubtitles.com（api_key + username + password），凭据未配置 |

当前配置（插件 API 实测）：`enabled=true, moviepilot_enabled=true,
opensubtitles_enabled=false, assrt_enabled=true`，源优先级
`["assrt", "moviepilot", "opensubtitles"]`。

### ChineseSubFinder（v0.55.3，2023-12-01 后停滞）

- Docker Hub 实测：`latest` 与 `v0.55.3` 镜像均发布于 **2023-12-01**，此后无新
  release —— **项目已停止维护**，不能指望升级获得新源或修复 a4k。
- 当前每小时源探测（CSF 日志实测）：
  - `xunlei`（迅雷字幕）：alive，111–789 ms —— **可用**
  - `shooter`（射手）：alive，789–832 ms —— **可用**
  - `assrt`：alive，但 `UserInfo.Quota: 4–5`（见下）
  - `a4k`：**EOF 失败**（站点侧故障，直连/代理均不可达）
- 配置里仅有 `assrt_settings` 与 `subtitle_best_settings` 两个源配置项，
  其余为内置源；容器**未配置代理环境变量**，被墙源全部直连失败。

### assrt 免费 API 配额（关键限制）

CSF 日志（2026-08-16 09:41 / 10:41）：

```text
assrt CheckAlive UserInfo.Status: 0 UserInfo.Quota: 4
assrt CheckAlive UserInfo.Status: 0 UserInfo.Quota: 5
```

免费 Token 每日配额约 **5 次**，且 MP 与 CSF 大概率共用同一账号。assrt 只能作
兜底源，不能作为主力。

## 字幕站连通性实测（2026-08-16，rock5c 实测）

| 站点 | 直连 | 代理 | 结论 |
| --- | --- | --- | --- |
| api.assrt.net | 302 | 200 | 可达（API 正常重定向） |
| www.a4k.net | 000 | 000 | **站点侧故障**，已挂 |
| www.zimuku.la | 410 | 000 | 主站下线（Gone）；zimuku.ws/cn/tv 全 000、zimuku.org 404 → **字幕库整体不可用** |
| subhd.tv | 000 | 200 | 直连被墙，代理可达 |
| subhdtv.com | 200 | 200 | **新域名直连可用** |
| www.tvmao.com | 000 | 000 | 不可达 |
| api.opensubtitles.com | 404 | 404 | **API 可达**（根路径 404 为正常，需凭据） |
| www.podnapisi.net | 000 | 000 | 不可达 |
| subdl.com | 403 | 200 | 直连被 Cloudflare 拦，代理可达 |
| yysub.net | 000 | 200 | 直连超时，代理可达 |
| www.opensubtitles.org | 401 | 401 | 可达（需登录，老协议站点） |

## 源评估

| 源 | 可用性 | 接入途径 | 评级 |
| --- | --- | --- | --- |
| **opensubtitles.com** | API 可达，免费注册 | MP SubtitleAssistant 原生支持，零代码 | ★★★ 推荐 |
| **SubHD**（subhdtv.com） | 直连 200 | CSF 老版本内置 subhd 源走 subhd.tv（代理可达）；或将来接入其它工具 | ★★ 备选 |
| xunlei / shooter | 已可用 | CSF 现有内置源 | 保留 |
| assrt | 配额 5 次/天 | 现有 | 保留兜底 |
| a4k / zimuku / tvmao / podnapisi | 站点已挂 | 无 | 从关注清单移除 |
| yysub / subdl / subhd.tv | 需代理 | CSF 加代理后可解锁 | ★ 低优先 |

## 推荐方案

### 方案 A（推荐，立即可做，零 Nix 改动）：启用 SubtitleAssistant 的 opensubtitles 源

opensubtitles.com 是仍在维护的国际大源（英文/多语字幕覆盖最全），
SubtitleAssistant 已原生支持，只需注册与填凭据。

步骤：

1. 注册 https://www.opensubtitles.com 免费账号（邮箱即可）。
2. 在个人设置页生成 API key（`api_key`），用户名/密码即注册凭据。
3. MoviePilot → 插件 → SubtitleAssistant → 填入 `api_key` / `username` /
   `password`，启用 `opensubtitles` 源，保存。
4. 建议将源优先级调整为 `["moviepilot", "opensubtitles", "assrt"]`
   （assrt 配额小，放最后兜底）。
5. 验证：字幕助手页面对一部已知缺字幕的电影手动搜索，确认 opensubtitles 返回
   候选并可下载。

注意：免费额度有限（社区通识约 20 次下载/天，搜索另有次数限制），具体以注册页
说明为准；中文资源覆盖一般，主要补充英文/多语字幕缺口。

### 方案 B（可选，需 Nix 改动）：给 CSF 容器加代理，解锁被墙源

- 在 rock5c 主机配置（如 `hosts/rock5c/media-apps.nix`）为
  `chinesesubfinder` 容器添加 `HTTP_PROXY`/`HTTPS_PROXY =
  socks5h://192.168.0.1:1080`（与 MoviePilot 容器一致）。
- 可激活：subhd.tv、yysub、subdl。
- 局限：CSF v0.55.3 的 subhd 实现具体域名未核实；项目停滞，中文源整体萎缩，
  收益有限。
- 涉及部署与验证，需用户确认后实施。

### 方案 C（不推荐）：Bazarr 回归

Bazarr 源丰富，但 2026-08-09 迁移已决定由 SubtitleAssistant 替代并停止，
回归与"单一 MoviePilot 链路"的既定方向冲突，成本高。

## 决策点（待用户确认）

1. 是否注册 opensubtitles.com 并启用方案 A（纯 UI 操作，可立即执行）。
2. 是否实施方案 B（给 CSF 加代理，属配置改动，需部署验证）。
3. a4k / zimuku 已死源：CSF 无法从配置关闭内置 a4k（v0.55.3 无按源开关），
   每小时 CheckAlive 报错为已知噪音，暂接受。

## 附录：证据索引

- CSF 镜像停滞：Docker Hub `allanpk716/chinesesubfinder` tags，最新
  `latest`/`v0.55.3` 发布于 2023-12-01。
- assrt 配额：CSF 日志 `assrt CheckAlive UserInfo.Quota: 4~5`。
- SubtitleAssistant 源支持：容器 `/app/app/plugins/subtitleassistant/`
  （config.py 的 PluginConfig 与 sources/opensubtitles.py 的 BASE_URL）。
- 连通性：本机 rock5c 实测（见上表）。
