# 客户端设备入网指南

非内网设备通过 ZeroTier 加入 LTNET 网络，获得 `198.18.0.x` 地址后即可访问所有
`accessibleBy = "private"` 的服务（下载、媒体、管理等）。

## 前置条件

- 设备能访问互联网
- 网络 ID：`466270de75000001`
- 控制器：colocrossing（端口 9994）
- 地址分配：IPv4 `198.18.0.<index>`，IPv6 `fdd8:1938:4e88::<index>`

## 各平台安装与入网

### Android

1. 从 F-Droid 或 GitHub Releases 安装 [ZeroTier One](https://github.com/zerotier/ZeroTierOne/releases)（Play Store 版本过旧）
2. 打开 app → 右上角 `+` → 输入网络 ID `466270de75000001` → 勾选 **Allow Managed Routes** → Join
3. 记下设备 Node ID（app 左上角 10 位十六进制）
4. 等待管理员授权（见下方"授权"）
5. 授权后状态变为 `OK`，获得 `198.18.0.x` 地址

> 注意：Android 的 ZeroTier 会创建 VPN 接口，所有流量可能走 LTNET 默认路由。
> 如果只想访问内网服务而不影响正常上网，入网后在 app 中取消 **Allow Default Route**。

### iOS / iPadOS

1. App Store 搜索 **ZeroTier One** 安装
2. 打开 app → 右上角 `+` → 输入 `466270de75000001` → 开启 **Allow Managed Routes** → Join Network
3. 系统弹出 VPN 权限请求 → 允许
4. 记下 Node ID（app 主界面顶部）
5. 等待管理员授权
6. 授权后网络状态显示 `OK`

> iOS 的 ZeroTier 以 VPN 形式运行。如果默认路由被推送，所有流量会经过 LTNET。
> 目前控制器推送了 `0.0.0.0/0 via 198.18.0.115`（ml-home-vm），iPhone 上建议
> 在 ZeroTier 设置中关闭 **Allow Default Route**，仅保留托管路由。

### Windows

1. 从 https://www.zerotier.com/download/ 下载 MSI 安装包并安装
2. 以管理员身份打开 PowerShell：
   ```powershell
   zerotier-cli join 466270de75000001
   ```
3. 获取 Node ID：
   ```powershell
   zerotier-cli info
   ```
4. 等待管理员授权
5. 验证：
   ```powershell
   zerotier-cli listnetworks
   # 状态应为 OK，IP 为 198.18.0.x
   ipconfig | findstr "ZeroTier"
   ```

> Windows 上 ZeroTier 创建虚拟网卡，托管路由自动生效。如果不需要默认路由，
> 在 ZeroTier Central 或本地 `zerotier-cli set 466270de75000001 allowDefault=0` 关闭。

### Linux（非 NixOS）

1. 安装：
   ```bash
   curl -s https://install.zerotier.com | sudo bash
   ```
2. 加入网络：
   ```bash
   sudo zerotier-cli join 466270de75000001
   ```
3. 获取 Node ID：
   ```bash
   zerotier-cli info
   ```
4. 等待管理员授权
5. 验证：
   ```bash
   zerotier-cli listnetworks
   ip addr show zt*
   ping 198.18.0.115  # ml-home-vm
   ```

### Linux（NixOS，纳入仓库管理）

如果设备要作为正式 host 纳入配置仓库，按 [新主机接入规范](./new-host-standard.md) 操作。
如果只是临时客户端，使用上方非 NixOS 方法即可。

### macOS

1. 从 https://www.zerotier.com/download/ 下载 pkg 安装，或：
   ```bash
   brew install --cask zerotier-one
   ```
2. 加入网络：
   ```bash
   sudo zerotier-cli join 466270de75000001
   ```
3. 获取 Node ID：
   ```bash
   zerotier-cli info
   ```
4. 等待管理员授权
5. 验证：
   ```bash
   zerotier-cli listnetworks
   ifconfig | grep -A2 "zt"
   ping 198.18.0.115
   ```

> 当前 MacBook 已入网：index=200，地址 `198.18.0.200`，Node ID `174ea952dd`。

## 管理员授权流程

新设备加入后处于 `PENDING` 状态，需要在控制器中授权并分配固定地址。

### 步骤 1：获取新设备的 Node ID

设备入网后，在设备上运行 `zerotier-cli info` 获取 10 位 Node ID。

### 步骤 2：编辑 secrets 中的 additional-hosts

在 `nixos-secrets/zerotier-additional-hosts.nix` 中添加条目：

```nix
[
  # 已有条目
  {
    name = "molishanguang-macbook";
    index = 200;
    zerotier = "174ea952dd";
  }

  # 新设备示例
  {
    name = "my-iphone";        # 设备标识名
    index = 201;               # 唯一编号，决定 198.18.0.201
    zerotier = "xxxxxxxxxx";   # 设备 Node ID
  }
]
```

**约束：**
- `index` 不能与现有主机冲突（查看 `hosts/*/host.nix` 和已有 additional-hosts）
- `name` 用于标识，不参与 DNS 或路由
- 提交到 secrets 仓库并推送

### 步骤 3：部署控制器

```bash
# 在 ml-builder 上
cd /nix/src/nixos-config
nix flake lock --update-input secrets
sudo SSH_AUTH_SOCK=$SSH_AUTH_SOCK NIX_SSHOPTS='-F /dev/null -o StrictHostKeyChecking=no' \
  nix run .#colmena -- apply --on colocrossing
```

部署后控制器自动推送新成员配置，设备几秒内变为 `OK` 并获得固定 IP。

### 步骤 4：验证

在设备上：
```bash
zerotier-cli listnetworks   # 状态 OK
ping 198.18.0.115           # ml-home-vm 可达
```

在浏览器中访问任意 private 服务：
```
https://bt.ml-home-vm.zhyi.cc      # qBittorrent
https://jellyfin.zhyi.xin # Jellyfin
https://sonarr.ml-home-vm.zhyi.cc   # Sonarr
```

## 访问路径

```text
设备 (ZeroTier 198.18.0.x)
  → DNS: *.ml-home-vm.zhyi.cc → jpvm.zhyi.cc (36.50.85.113)
  → jpvm nginx (TLS 终止，源 IP 198.18.0.x 命中 private 白名单)
    → colocrossing (LTNET 198.18.0.120)
      → ml-home-vm (LTNET 198.18.0.115，实际服务)
```

## 常见问题

| 问题 | 原因与解决 |
|------|-----------|
| 状态一直是 `REQUESTING_CONFIGURATION` | 控制器未授权；检查 additional-hosts 是否已部署 |
| 状态 `OK` 但无法 ping 198.18.0.115 | 检查设备是否拿到了 198.18.0.x 地址；路由是否生效 |
| 能 ping 但浏览器打不开 | DNS 解析问题；确认设备能解析 `*.zhyi.cc`（走公网 DNS 即可） |
| 入网后所有流量变慢 | 默认路由被推送；关闭设备的 Allow Default Route |
| 手机锁屏后断连 | ZeroTier 后台被系统杀死；Android 需关闭电池优化，iOS 需保持 VPN 开启 |

## 安全说明

- ZeroTier 通信全程加密（Curve25519 + AES）
- 设备只获得 `198.18.0.x` 内网地址，不暴露任何公网端口
- 所有 Web 服务仍走 HTTPS（Let's Encrypt 证书）
- 撤销设备：从 `zerotier-additional-hosts.nix` 删除条目并重新部署 colocrossing
