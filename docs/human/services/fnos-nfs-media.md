# 飞牛 fnOS NFS 媒体库接入

PVE VM 101（`fn-os`）通过 NFS 挂载 QNAP 媒体库，供飞牛影视扫描。

## 网络

- 静态 IPv4：`192.168.0.41/24`，网关 `192.168.0.1`。
- Web UI：`http://192.168.0.41:5666`。
- 路由器 Kea 已按 MAC `bc:24:11:a4:51:4e` 预留同一地址。

## NFS

- 服务端：`192.168.0.40`。
- Export：`/nixos`（与 router/opi5p/rock5c 相同）。
- QNAP 白名单需放行客户端：`192.168.0.41`。
- Guest `/etc/fstab`：

```text
192.168.0.40:/nixos  /vol1/1000/Photos  nfs  noauto,x-systemd.automount,nofail,_netdev,vers=4.1  0  0
```

## 飞牛影视

1. 登录 `http://192.168.0.41:5666`。
2. 打开飞牛影视，新建媒体库。
3. 电影库路径：`/vol1/1000/Photos/media-radarr`。
4. 剧集库路径：`/vol1/1000/Photos/media-sonarr`。
5. 触发扫描后验证影片可播放。
