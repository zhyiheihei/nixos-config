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

## 默认内容

seed 服务（`sublinkpro-seed.service`）在全新数据库上自动创建：

- 三个 VLESS xhttp 节点：`jpvm`、`usvm`、`colocrossing`
  （443 端口，`/ray`，`stream-up`，UUID 来自 SOPS `v2ray-key`）
- 订阅「统一订阅」，使用官方模板路径
  `./template/clash.yaml` / `./template/surge.conf`
- 分享 token：由 `default-pw` 转小写得到（官方 `/c/` 查询会把 token 转小写）
- 分流规则：`zhyi.cc`/`zhyi.xin`/`zhyi.dn42` 直连、内网段直连、
  `GEOIP,CN` 直连、其余走代理

## 添加 Clash 订阅

1. 登录 `https://sub.zhyi.xin/`，进入「机场管理」添加 Clash/mihomo 订阅链接。
2. 在「订阅管理」编辑「统一订阅」，把新机场加入该订阅。
3. 使用「分享管理」的 token 生成最终统一订阅链接。

## 运维

- 容器：`podman-sublinkpro.service`，镜像
  `docker.io/zerodeng/sublink-pro:latest`，内存限制 1 GiB、PID 限制 512。
- 数据：`/var/lib/sublinkpro/{db,template,logs}`，模板文件首次启动写入。
- 重置：服务刚部署、尚无用户数据时，可停止容器与 seed 后删除
  `/var/lib/sublinkpro/db`，再执行 `systemctl start podman-sublinkpro` 和
  `systemctl start sublinkpro-seed` 全新初始化。
- 验证：

```bash
systemctl status podman-sublinkpro sublinkpro-seed --no-pager
curl -sS --get http://127.0.0.1:13818/c/ \
  --data-urlencode "token=$SUBLINK_SHARE_TOKEN" \
  --data-urlencode "client=clash" | head
```

## 备注

2026-08-10 首次部署时 colocrossing 曾失联并多次重启，回滚后本次以受限容器重新
部署；若再次出现主机级失联，先看服务商控制台日志，不要直接重复部署。
