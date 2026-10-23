# opi5p（Orange Pi 5 Plus，RK3588，16 GiB）

家庭唯一的 Web 边缘 + aarch64 原生构建机 + 出站代理入口。`hosts/opi5p/*.nix`
不写注释，理由记录在本文件。

## 家庭 Web 边缘

- 家宽 WAN 443 被运营商封禁，公网只能经 8443 进入；router 把公网 `{80,443}`、
  `4000`、`8443` 与内网 hairpin 443 全部 DNAT 到本机（见
  [domain-service-layout](../domain-service-layout.md)）。
- nginx 的 vhost 每个 HTTPS 端口只能有一个监听，所以 `with8443` 在
  `services.nginx.virtualHosts` 层基于 `lantian.nginxVhosts` 重新生成，给每个启用
  TLS 的 vhost 追加一条 8443 监听（仅本主机生效）。443 与 8443 服务同一套证书与
  路由，端口不变，不需要改写 Host/SNI。
- 公网可见性由 [`hosts/opi5p/public-vhosts.nix`](../../../hosts/opi5p/public-vhosts.nix)
  的名单统一决定：名单内域名 `accessibleBy = mkForce "public"`，名单外维持各模块
  自己的取值（上游模块多为 `private`，只放行 LTNET/ULA/lo）。因为 router 对 DNAT
  流量做 masquerade，边缘看到的源地址恒为 `192.168.0.1`，入口侧源地址 ACL 在家庭
  入口上等价于「全开/全关」，所以认证一律落在 vhost 层（OAuth / Basic Auth /
  应用自身登录）。
- 后端回源一律走内网或 LTNET，不回源公网 DNS（避免环路）：
  - `jellyfin.zhyi.xin` → chromebox `jellyfin-backend.chromebox.zhyi.xin`
    （`ltnet.IPv4:8096`，该 vhost 只放行 LTNET 源）。2026-10-23 撤掉了 rock5c
    中间那一跳。
  - `memos` / `wallos` → dragon-q8b 内网 443（HTTPS + SNI）。
  - `tachidesk` → chromebox（HTTPS + SNI，叠 basicAuth）。
  - `vaults3` → router `192.168.0.1:9000`（VaultS3 原生跑在 router 上，本机只做
    TLS 前沿）。
  - `qnap` → `192.168.0.40:8080`（QNAP 自带登录）。
  - `openlist` / `dav` → 本机进程与 unix socket。
  - `linkr` → 家庭内网固定 IP（`192.168.0.42`）。不用 mDNS 名：nginx 启动时即解析
    `proxyPass` 主机名，mDNS 抖动会炸 nginx。
- `networking.hosts` 把 `vaults3`/`jellyfin`/`qnap`/`tachidesk` 钉到本机地址，纯粹
  是给本机进程解析自己用（避免走 hairpin），不是绕过链路问题。
- `dav.zhyi.xin` 公共名在 `webdav` 模块只生成了 `dav.opi5p.zhyi.xin`，本机补齐
  公共名 vhost，代理同一个 `webdav.sock`，凭据同全舰队 htpasswd。
- 两级子域（如 `linkr.opi5p.zhyi.xin`）不在 `zerossl-zhyi.xin` 通配范围，用本机
  通配证书。

## 出站代理（v2ray）

全仓出站代理的统一入口（自 router 迁入）：本机跑 v2ray，其他主机经 router 的
SOCKS 入口或直连本机。

- `.NET` 应用（Jellyfin）不认 `socks5://` 环境代理，只能用 `http://` scheme 的
  HTTP CONNECT 代理；域名由 vless 出站端远端解析，绕开 TMDB 等 DNS 污染。routing
  规则与 inbound tag 无关，不需要改。
- 未匹配流量默认走第一个 outbound（`proxy`）；Xray 拒绝空的 `field` 规则
  （"no effective fields"）。
- v2ray 私钥由 v2ray 用户拥有：user namespace 会 unmap 该 uid，所以不做
  user-namespace 隔离。

## 构建与缓存

- **FOD 下载**走统一出站代理，但代理变量绝不喂给 nix-daemon：出站阻塞时连接不退，
  sshd/nix-daemon 连环孵化 OOM（两代硬件都复现），详见
  [outbound-proxy](../outbound-proxy.md)。
- nix-daemon 只补 `GOPROXY`（`goproxy.cn` 直连可达，不经 router 代理，避免上述
  OOM）：被分发到本机的 go-modules 类构建默认走 `proxy.golang.org`，其 IPv6 从本
  网络不可达，远程构建必失败（2026-09-06 ncps go-modules）。
- 私有 Attic 端点的 TLS 握手偶尔超过 nix 默认 5 秒，与 ml-builder 保持一致放宽，
  避免健康的私有缓存被过早禁用。
- **构建槽位**：本机承接 aarch64 原生构建，`max-jobs=1`（生产节点保护，见
  docs 2026-08-02 事故）；x86 与 aarch64-cross 全部外派 ml-builder。gRPC builder
  入口同样单槽（闸口在 `builder.toml`，daemon 的 `max-jobs` 拦不住 gRPC）。
- `extra-platforms` 显式置空：qemu binfmt 关闭时 minimal-components 不设该项，而
  nix-distributed 生成 machines-with-localhost 时强制读取该属性；本机是纯 aarch64
  原生构建。
- `ml-builder` 通用槽 2→1（2026-09-25）：多客户端（Hydra + 手动部署）预算叠加会
  超出 ml-builder 的 6×16 稳定包络引发 OOM，与 ml-laptop 同步收口。
- 不注册 qemu binfmt：本机是原生 aarch64 构建机，注册只会让原生构建走更慢的路径。
- 编译临时对象放 tmpfs，避开较慢的 eMMC/Btrfs；空闲内存留给其余服务，压力靠 zram。
- `optional-apps/hydra` 的 import 目前按用户要求停用。

## 网络与存储

- 两个板载网口同用 RTL8125 驱动，eth0/eth1 随 PCIe 探测顺序变化，所以按永久 MAC
  匹配成 `lan1`/`lan0`，给后续服务稳定命名。
- 静态 XOR 双 2.5G 聚合：交换机侧是 SKS3200-5E1X Trunk1（UI Port4+Port5，static）。
  该交换机 LACP 协商从未完成（Aggregated 列始终为空），只有静态聚合才有
  Aggregated 状态，与 ml-2700 的成功先例同款。MAC 钉在 `lan1` 的烧录地址上，
  ARP/交换机表在重启与 PCIe 探测顺序变化后保持稳定。
- **`networks.bond0` 必须带 `matchConfig.Name`**：否则空 `[Match]` 会歧义匹配
  `lan0`/`lan1`，把 slave 从 bond 里抢走（曾经的一次 boot 失联直接根因）。
- NAS 媒体库由 NAS 直接导出，本机挂同一共享（不经 ml-home-vm 中转）。挂载用
  `noauto` + automount：直接 mount 会卷入 ordering cycle（本机 bindfs 共享归
  local-fs 却依赖 remote 挂载），systemd 每次开机打断环后网络等待被删，挂载在地址
  未就绪时失败且永不重试。写法对齐 exam `lt-hp-omen`：无 `clientaddr`（boot 早期
  地址未配好会被 `mount.nfs` 拒绝），无 `idle-timeout`（bindfs 通过 requires 直接
  拉起本挂载，与 autofs 空闲卸载语义冲突）。
- `/mnt/storage.mount` 加 `StartLimitIntervalSec=0`：NAS 掉线窗口内反复 mount 会撞
  默认 5 次/10s 限流，automount 连带永久 failed。fileSystems 生成器产物用
  `asDropin` 下发。
- 本机 `boot.supportedFilesystems` 带 nfs（内核客户端），`nfs-utils` 提供
  `mount.nfs`，两者都保持主机级，不塞进共享模块。
- syncthing 模块生成的 bindfs 挂在 `/mnt/storage`（remote 挂载）之上却默认归
  `local-fs.target`，是 ordering cycle 的回边；主机级加 `_netdev` 把它归入
  remote-fs 链断环（共享模块不动）。
- **swap**：关 zram 改 NVMe swapfile。服务密度超物理内存时 zram 压缩会把 kswapd
  吃满一核、陷入 swap 风暴（见 docs/human/hardware/orangepi-5-plus-redroid.md）。
  swapfile 放独立子卷 `/nix/swap`：btrfs 快照不递归进子卷，避免快照含活动
  swapfile 造成的 "Text file busy"。首启按需创建（`swapDevices` 只激活已存在的
  文件），且必须关 `DefaultDependencies`，否则与 `basic.target` 构成排序环。

## 服务

- **Frigate NVR**（乐橙摄像头 ×2）：摄像头本地密码在
  `secrets/frigate.yaml`（key `bedroom-pw` / `livingroom-pw`），`rtspUrl` 里的 sops
  占位符由 sops 模板渲染替换。乐橙 App 里必须关闭 RTSP 加密（TLS），否则 frigate
  拉流失败。
- **One-KVM**：板载 HDMI RX 采集 + Type-C OTG HID/MSD（细节在 `one-kvm.nix`）。
  首启直接播种 app_config + 管理员，跳过 Web setup 向导（2026-09-11 用户决策）。
  实测 HDMI RX 采集是 `/dev/video0`（`stream_hdmirx`，分辨率自适应）；音频不启用
  （card0 `rockchip-hdmiin` 无 PCM 采集节点，板载 es8388 采的是板载 codec 而非被控
  机音频）；UDC 只有 `fc000000.usb` 一个，留空自动选；管理密码复用全舰队 sops
  `default-pw`；视频 60fps 是用户指定默认。0.2.6 镜像 WebRTC 模式冷启动会死锁，
  默认用 mjpeg 模式（实测 1080p60 稳定），需要时在 Web 界面切 H264/WebRTC。
- **ws-scrcpy**：浏览器镜像/控制 Android 设备。目标设备：本机 redroid（rk3588）、
  dragon-q8b redroid、手机无线 adb（启用后把手机 `IP:5555` 加进 `adbHosts`）；
  `192.168.0.41` 是尚未部署的待用 redroid 主机，先登记，设备起不来由 timer 重试。
- **OpenList + TaoSync**：`Documents/Pictures` 经 Syncthing 媒体盘只读挂载，定时
  同步到百度网盘（仅新增模式，删除不传染）。刷 token 走 OpenList 在线 API（外站）
  → 出站代理；百度上传国内直连豁免。TaoSync 只连 OpenList（podman 网关
  `10.88.0.1`），不出外站，因此不给它配代理——它缺 requests 型 SOCKS 支持，配了
  连本机引擎都会报错。OpenList 公开服务（8443 TLS 前沿 + Dex OAuth）；TaoSync
  上游明确警告不要暴露公网，保持 LTNET 私网。
- **EPD 看板**：家庭食品存储看板，REST API + WebUI（内网
  `food.opi5p.zhyi.xin`）+ 每日 0 点墨水屏推送 timer；BLE 推 NRF_EPD 墨水屏，
  服务私有不开公网；日程栏接标准 CalDAV（`cal.zhyi.xin`，Radicale，只读），密码用
  统一 `default-pw`。测试阶段免鉴权（`tokenFile = null`），转生产时用 sops 提供
  token 后启用。
- **媒体库目录**沿用已退役的 `sonarr`/`radarr` 名字：MoviePilot v3 与 Jellyfin 的
  库扫描仍按这两个路径组织 union，改名会断库。
- **bitmagnet 的 16 GiB PostgreSQL 库**读写密集，目录还是空的时候设 NOCOW，等
  PostgreSQL 在 NVMe 上初始化就晚了。
- **reDroid**：`lanInterface` 由公共模块动态解析（聚合后自动命中 bond0），是否
  彻底停用待用户定夺。
- 停用但保留注释记录的能力：`ignis`（Home payloads 存储）、`FlClash` 的
  `/FlClash/` WebDAV 目录预创建（MKCOL 405 被 webdav_client 当成功）、
  `radicale-calendar-sync` 的 sops ordering。
- 按用户 2026-10-22 要求跟随上游停用：`microsoft-rewards-script`、`resin`。

## 历史拓扑（媒体中心）

上游 `lt-home-vm` 的下载链在本仓演化成：qBittorrent 与 `*arr` 迁往
router/rock5c，由 MoviePilot v3 接管；tachidesk / peerbanhelper 迁至 dragon-q8b
（负载降压）；bitmagnet 三件套 2026-08-28 也迁到 dragon-q8b。本机保留为 rock5c
准备的 NFS 库目录与 postgres（immich / home-assistant 仍在用）。

## 主机密钥

2026-08-30 从 8-27 快照恢复 `etc/ssh`，主机钥匙回到原生 `mloC`
（SHA256:mloCmodzu1MrdnZUxwRfRoMQWORF9xKgS1UccjwIrBw）；secrets 全库已 rekey 到该
钥匙的 age 形式（secrets 仓 372bf21）。8-29 的 H7+p 私钥随 dragon 无持久化
`/root` 蒸发，已废止。

## 其他

- `host.nix` 的地域字段即使没有 dn42，server-role 的 BIRD 配置也会读取。
- 本机是 aarch64 原生 fallback 构建机：RK3588 承接构建脚本必须执行目标代码的
  derivation；专用构建路径仍是 ml-builder。2026-08-31 恢复 `nix-builder` 标签，
  aarch64 构建自 dragon-q8b 切回本机（dragon 8 GiB 天花板，构建期间 OOM 连环实证）。
