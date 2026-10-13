# 2026-10-13 全舰队大部署记录

本次是部署前确认规范（`tools/pre-deploy-check`，2026-10-13 确立）落地后的首次
全舰队部署。触发条件：双机重启（ml-laptop 与 ml-builder 均为当日开机）+ 用户
要求全量部署验证。本文记录过程与遇到的每个问题，供后续总结经验。

## 部署前确认（规范首次实战）

- `tools/pre-deploy-check` 首验即拦截真实故障：ncps ✓，ml-builder 报离线。
  当时机器已物理开机，工具报的是**构建通道死了**，而不是机器没开——这正是
  两项确认分开做的价值（详见问题 1）。
- 通道修复后复验通过，方才发起 make。

## 问题清单

### 1. ml-builder 开机后 LTNET 构建通道死亡（已修复）

**现象**：ml-builder 已物理开机，家庭 LAN 直连 192.168.0.50 ping/ssh 全通；
但 `ml-builder.zhyi.xin`（只解析 LTNET 地址 198.18.0.114 /
fdd8:1938:4e88::114）ssh 超时。远程构建走的就是这个域名，通道等于全断。

**诊断过程**（要点）：
- 本机到 router（198.18.0.112）LTNET ping 正常 → 本机侧 LTNET 整体健康；
- ml-builder 到 router LTNET ping 通但 rtt 752ms → 典型 PLANET 中继路径，
  说明 ml-builder 侧没有到本机的直连；
- ml-builder 的 ZT peers 里本机节点（08d6522fba）显示 DIRECT 但
  `lastTX -1`：只收不发，出站路径状态卡死；本机侧对 ml-builder 是 1ms
  健康双向 DIRECT。两侧 ZT 控制面 chatter 正常，数据面单侧死亡；
- 两机 nftables 均无过滤嫌疑，内核路由对称（`ip route get` 同形）。

**处理**：重启 ml-builder 的 zerotierone 无效；**双端**重启
zerotierone（`systemctl restart zerotierone`）后约 40 秒路径重建，
LTNET ssh 恢复。

**结论**：双机重启后 ZeroTier 直连路径可能单侧卡死，控制面正常极具迷惑性。
判据：`zerotier-cli peers` 看对端 `lastTX -1`（只收不发）即出站路径卡死，
单端重启无效就双端重启。此问题写入 AGENTS.md 部署前确认的排障上下文。

### 2. `make all-all` 会话超时（7200s），但部署本身没有失败

**现象**：`make all-all` 跑满 2 小时被会话杀掉，当时看不到任何输出。

**事后核验**（`.gcroots/` + 逐台 ssh）：
- ml-builder 内核日志 09:00–13:30 **0 次 OOM**，nix-daemon 5056 行构建记录
  → 超时纯粹是构建慢（当日 18 台闭包 13:23–13:27 全部构建完成），不是构建
  机 OOM；
- 18 台闭包构建完成后推送/apply 阶段陆续推进，最终 14/20 台与当日闭包一致。

**教训**：
1. 会话里跑全量部署必须考虑墙钟：以后长部署用 `nohup`/独立终端跑，会话里
   只轮询 `.gcroots/` 状态与逐台 `readlink -f /run/current-system`；
2. 判断部署卡没卡死的口径是 `.gcroots/node-*` 时间戳与各机
   current-system，不是命令是否还活着；
3. 构建机 OOM 的预案（用户 2026-10-13 指示）：绝不允许把 OOM 包改成本机
   构建；直接用 exam（上游）的缓存——对齐过的包与上游逐字一致，上游缓存
   里必然有。若上游缓存也没有，说明对齐失败了，回到对齐作业，不要绕。
   （exam 缓存经 ncps 的 upstream 链自动回源，本机 nix 无感。）

### 3. greencloud-jp `vaults3-init-nix-cache` Failed（既有瑕疵，atticd 无恙）

**现象**：部署切换后 13:37 报 `BucketAlreadyExists`，exit 254，整机
degraded。七天内首次失败（Oct 7 那轮没有）。

**根因**（hosts/greencloud-jp/configuration.nix:185）：脚本先
`head-bucket`，失败才 `create-bucket`。切换重启时 head-bucket 瞬时失败
（vaults3 刚重启未就绪，耗 24s 超时），随后 create-bucket 时桶已存在，
脚本不认 `BucketAlreadyExists` 直接退出非零。

**影响**：无。atticd `wants=`（非 requires）照常启动且 active，
attic.zhyi.xin 正常。

**待办**：把 create-bucket 的 `BucketAlreadyExists` 视为成功（失败后再
head-bucket 一次，通即 exit 0）。属 fork 自维护脚本的小幂等修正，可与
下次 greencloud-jp 部署一并做。

### 4. greencloud `rsync@<conn>` 单连接瞬断（transient，不处理）

socket 激活的 rsync 单连接实例失败（198.18.0.124:54990 → :873），客户端
连接中断的常态噪音，非配置回归。rsync 模板实例失败本身就允许，下次连接
生成新实例。

### 5. lubancat1 `rsync-nix-sync-servers` exit 12（观察项）

13:39 跑挂（rsync 协议错，exit 12），跑了 1m10s。与 2026-10-07 巡检
rock5c 的同类失败（LTNET 未就绪的既有独立问题，见 inspection-fleet 与
NFS/bindfs 结论 #185）同族。属定时任务，等下一轮跑成功即可消掉；若连续
失败再查。

### 6. pre-commit hook 二进制被 GC

commit 时 `.git/hooks/pre-commit` 指向的 store path
（pre-commit-4.6.2）已被垃圾回收，hook 报「没有那个文件或目录」。

**处理**：`nix run nixpkgs#pre-commit -- install` 重装 hook wrapper。
因本机 nixpkgs rev 与当年生成时一致，重建出**同一个** store path，无需
重新生成 `.pre-commit-config.yaml`（该文件 DO NOT MODIFY）。

### 7. git push 网络问题（未完结）

SSH 直连 github.com 挂起超时；按既定规矩转 HTTPS +
`https_proxy=socks5h://127.0.0.1:1080`，遇 askpass 取不到凭据
（gh credential helper 未接通）。提交 931411aa1（部署前确认规范）留在
本地，按用户指示不执着推送，网络恢复后补推。

### 8. 全部构建失败的真正根因：flake.lock 未对齐到上游生效的 nixpkgs 节点（已修复）

**现象链**：obs-noise（GCC discarded-qualifiers）→ 修 overlay 后 vscode
（patchPhase 静默死，structuredAttrs 回归）→ vtk（cmake 找不到 PEGTL）接
连失败，全部发生在 ml-builder。

**用户判定**：上游构建成功并部署了，不需要修 nixpkgs bug，一定是对齐
缺失。

**根因**：fork 与 exam 的 flake.lock nixpkgs 节点错位。exam 锁里有
`nixpkgs`（545c226a，github nixos-unstable-small）和 `nixpkgs_2`
（151fa4e8ddfd，26.11pre1086391 频道 tarball）两个节点，root 实际生效的是
**nixpkgs_2**（exam 自己的 AGENTS.md 第 62 行明示；仅比对同根同名的
nixpkgs 节点会得出 545c 的错误对齐目标，还会在 545c 上得出
services.hydra-builder 选项不存在的连锁误诊）。fork 今晨 nix flake update
把锁拉到频道 HEAD（6510408d/7fd4004d），脱离了上游构建验证过的世界，
vtk/vscode/obs-noise 的破损都是两个 rev 之间引入的 nixpkgs 回归。

**修复**：把 exam 的 nixpkgs_2 节点整体（locked+original，original 同为
频道 URL 不会触发重锁）复制到 fork 的 nixpkgs_4，求值立即恢复。中途的
55-cuda-pascal 修改（functionArgs 反射包装）已回退——原 overlay 在正确锁
上本来就工作。

**教训**：对齐锁时不能只看节点名，必须解析 root inputs 的引用链取生效
节点；上游的 nixpkgs rev 未知时先看上游 AGENTS.md/文档有没有明示。

### 9. exam-check 对齐审计两层盲区（已修复）

obs-noise 的上游补丁在 8fca17826（2026-10-06）加进 overlays/50-general.nix，
审计没拦住：① 默认模式只审计 A/D/R 文件结构，对既有文件内的 M hunk 不设
防；② upstream 模式对 allowlist 登记过的文件整文件豁免，known diff 不出
示。修复：known 文件归一化 diff 全文出示；M 清单作为同步待办列出。
修复后立即曝光 50-general.nix 还有五处曾漏跟的 hunk
（clickhouse-lts/dump1090-fa/grafana-loki/hydra-oidc/hydra-queue-runner），
已逐字补齐（现为上游全文减已登记豁免的 mpv 块）。

### 10. ncps 冷缓存回源慢导致 narinfo 超时（非故障，已定性）

**现象**：用户 make local 时大量 `unable to download ...narinfo: Timeout
was reached (28)`，5 秒超时重试。

**定性**：ncps 本体健康（服务 active，持续推进 download of nar
complete）。慢的根源：① 锁对齐后 nixpkgs 换到 pre1086391，缓存全冷，逐
NAR 回源；② ncps 上游抓取依赖 rock5c 代理
（systemd Environment HTTP(S)_PROXY=http://192.168.0.64:7892），家宽直连
cache.nixos.org/国内镜像全部停滞，经代理实测 ~1.8MB/s/流；③ 回源高峰期
narinfo 响应排队超 5 秒。ncps 日志另有大料 sqlite 自修复（mismatch
detected fixing narinfo size / missing FileHash backfilling），一次性成本。

**运行含义**：rock5c 代理挂掉 = 全舰队无二进制缓存；部署前确认第 1 项
（ncps 可用）应包括代理连通性。此结论已入项目记忆。

## 结果

| 主机 | 状态 |
| --- | --- |
| chromebox / dragon-q8b / google / greencloud / greencloud-jp / hostdare / lubancat1 / ml-builder / opi5p / rock5c / router / tencent / tencent-cn / volcengine | ✓ 已部署，与当日闭包一致，is-system-running 正常（greencloud-jp 见问题 3，greencloud 见问题 4，lubancat1 见问题 5） |
| ml-laptop | make local 执行中（另起会话），落地后与当日闭包一致 |
| h28k / opi03 / pve-5700u / taishanpi / ml-2700 | ssh 不可达，按用户指示跳过，待机器上线后补部署（ml-2700 需先补建当日闭包） |
| pve-2700 | manualDeploy，按规矩不随全量部署 |

## 经验沉淀（供后续规范吸收）

1. 部署前确认两项（ncps / ml-builder）各自都能拦住不同的真实故障，不能合并
   成一个「机器在线」检查。
2. ZeroTier 单侧路径卡死（lastTX=-1）是双机重启后的现实故障模式，双端重启
   是标准恢复动作。
3. 全量部署的墙钟管理：长跑脱离会话，会话只轮询状态。
4. 构建机 OOM 包的处理铁律：exam 缓存 → 没有 = 对齐失败 → 回炉对齐。
