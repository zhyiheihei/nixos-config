# lubancat1（鲁班猫，家庭 LAN 静态主机）

`hosts/lubancat1/*.nix` 不写注释，理由记录在本文件。

- 首启的 DHCP 清点已完成：把本板移出 router 的动态 `.100-.249` 池，用与其他物理基础
  设施主机相同的静态 LAN 布局。
- 媒体库与下载链在 NAS 上（与 rock5c 给 MoviePilot 用的同一份直接 NFS 挂载）；挂载保持
  可用，供后续服务使用。
- `noauto` + automount：裸 mount 在 NAS 未就绪时失败且不重试，写法对齐 exam
  `lt-hp-omen`（同 opi5p 修复，`c72df01ca`）。
- `/mnt/storage.mount` 加 `StartLimitIntervalSec=0`：automount 触发的 mount 失败不再撞
  5 次/10s 限流，NAS 恢复后访问即自愈。
- 地域字段即使没有 dn42，server-role 的 BIRD 配置也会读取。
