# SublinkPro 订阅面板（sub.zhyi.xin）

## 概览

`sub.zhyi.xin` 由 colocrossing 上的 SublinkPro 提供，用来管理 Clash/mihomo
订阅并生成统一订阅。入口经过仓库 OAuth 代理，面板内部登录账号为 `admin`，
密码与其它面板统一使用 `default-pw`。

- 管理页面：`https://sub.zhyi.xin/`
- 统一订阅地址：见 colocrossing 上
  `/var/lib/sublinkpro/unified-subscription.txt`
- 统一订阅格式：`https://sub.zhyi.xin/c/?token=<lowercase default-pw>&client=clash`
  （也支持 `client=v2ray`、`client=mihomo`）

## 当前内容（2026-08-13 调整后）

「统一订阅」当前组成（全部通过官方 API 配置，未改动数据库）：

- 自建节点：`jpvm`、`usvm`、`colocrossing`（group=overseas，三个 VLESS xhttp
  节点，443 端口，`/ray`，`stream-up`，UUID 来自 SOPS `v2ray-key`）
- 机场节点：机场 `xsus`（id=1，`xs.sujieok.cn`，每 12 小时自动拉取）——订阅
  通过 `airports=1` 挂载，机场新增节点会自动进入统一订阅，无需手动添加
- Clash 模板：`./template/unified-clash.yaml`——**分流规则与机场 xsus 完全一致**
  （机场 10226 条规则原样保留），代理组沿用机场 10 个组的结构
  （🔰 节点选择 / ♻️ 自动选择 / 🌍 国外媒体 / 🌏 国内媒体 / Ⓜ️ 微软服务 /
  📲 电报信息 / 🍎 苹果服务 / 🎯 全球直连 / 🛑 全球拦截 / 🐟 漏网之鱼），
  组成员用 `__ALL_PROXIES__` 注入全部节点（含自建节点，可被选中），并去掉
  机场配置里的「剩余流量/套餐到期」等伪成员
- Surge 模板：`./template/surge.conf`（seed 自带，未随机场规则）
- 分享 token：由 `default-pw` 转小写得到（官方 `/c/` 查询会把 token 转小写）

seed 服务（`sublinkpro-seed.service`）在全新数据库上仍会创建三个自建节点、
「统一订阅」（初始模板 `./template/clash.yaml`）和分享 token；上述调整在 seed
之后通过 API 完成。seed 幂等，重启不会覆盖「统一订阅」的模板引用与机场挂载。

## 同步机场分流规则

统一订阅的 Clash 规则来自模板 `unified-clash.yaml`，它由机场 xsus 的 Clash
订阅（`https://xs.sujieok.cn/...`）生成。机场更新规则后需要重新同步：

1. 在 colocrossing 上抓取机场 Clash 配置（服务器直连，与机场拉取同源）：
   ```bash
   curl -sS -L -m 60 -A "clash-verge/2.0.0" "<机场URL>" -o /tmp/xsus-clash.yaml
   ```
2. 重新生成模板内容：保留机场 `rules:` 原样，proxy-groups 重建为
   `__ALL_PROXIES__` 结构（参照上一节描述），然后通过官方 API 更新：
   ```bash
   . /run/secrets/rendered/sublinkpro-env
   login=$(curl -fsS -X POST http://127.0.0.1:13818/api/v1/auth/login \
     -d "username=admin" --data-urlencode "password=$SUBLINK_ADMIN_PASSWORD")
   token=$(printf '%s' "$login" | jq -r '.data.accessToken')
   curl -fsS -H "Authorization: Bearer $token" -X POST \
     http://127.0.0.1:13818/api/v1/template/update \
     --data-urlencode "oldname=unified-clash.yaml" \
     --data-urlencode "filename=unified-clash.yaml" \
     --data-urlencode "category=clash" \
     --data-urlencode "text@/tmp/unified-clash.yaml"
   ```
   订阅的 `config` 引用不变，无需改动订阅。
3. 验证（规则条数应与机场一致，约 10226）：
   ```bash
   curl -sS --get http://127.0.0.1:13818/c/ \
     --data-urlencode "token=$SUBLINK_SHARE_TOKEN" \
     --data-urlencode "client=clash" | grep -c '^    - "'
   ```

## 添加其它订阅来源

1. 登录 `https://sub.zhyi.xin/`，进入「机场管理」添加新的 Clash/mihomo
   订阅链接（配置定时拉取）。
2. 在「订阅管理」编辑「统一订阅」，把新机场（`airports=<ID>`）或新节点
   （`nodeIds=<ID,...>`）加入该订阅。
3. 新来源的节点会由 `__ALL_PROXIES__` 自动进入各代理组，无需改模板；若机场
   规则有变，按上一节重新同步模板。

## 运维

- 服务：`sublinkpro.service`（原生二进制，来自 zhyi-packages；`podman-sublinkpro`
  单元保留但被禁用，仅用于回滚），内存限制 1 GiB、PID 限制 512。
- 数据：`/var/lib/sublinkpro/{db,template,logs}`，模板文件首次启动写入。
- 重置：服务刚部署、尚无用户数据时，可停止服务与 seed 后删除
  `/var/lib/sublinkpro/db`，再执行 `systemctl start sublinkpro` 和
  `systemctl start sublinkpro-seed` 全新初始化（注意：会丢失机场与模板调整，
  重置后需重新执行「同步机场分流规则」）。
- 验证：

```bash
systemctl status sublinkpro sublinkpro-seed --no-pager
curl -sS --get http://127.0.0.1:13818/c/ \
  --data-urlencode "token=$SUBLINK_SHARE_TOKEN" \
  --data-urlencode "client=clash" | head
```

## 备注

2026-08-10 首次部署时 colocrossing 曾失联并多次重启，回滚后本次以受限容器重新
部署；若再次出现主机级失联，先看服务商控制台日志，不要直接重复部署。
