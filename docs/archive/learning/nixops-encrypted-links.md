# nixops-encrypted-links 学习笔记

## 1. 是什么

`nixops-encrypted-links` 是 adisbladis 移植的 NixOps 1.x 的
`encryptedLinksTo` 模块：在 NixOps 管理的机器之间建立 SSH 加密
点对点隧道。MIT，4 star，Python + Nix，2021-02 后基本停更。

```nix
deployment.encryptedLinksTo = [ "machine2" ];
```

隧道是双向的，只需要一端声明；NixOps 会配 `/etc/hosts`，让对端
主机名解析到隧道 IP，并为每台机器加
`<machine>-encrypted` / `<machine>-unencrypted` 别名。

## 2. Python 侧（plugin.py / lib.py）

- 插件用 hooks：`post_wait` 时给机器生成/上传 VPN key
  （`/root/.ssh/id_charon_vpn`）；`physical_spec` 时按整个网络
  生成配置；
- `mk_matrix` 计算：
  - 隧道 IPv4：`192.168.<105 + index/256>.<index%256>`（依赖机器
    `index`）；
  - tunnel 设备号：`10000 + 对端 index`；
  - hosts 别名、`authorized_keys`（对端能建立 tunnel）、
    `trustedInterfaces`（tun 设备）、内核模块 `tun`、
    `knownHosts` 条目；
  - 自动去重：两端都声明时只建一条。

## 3. Nix 侧

- `options.nix`：`deployment.encryptedLinksTo` 选项；
- `ssh-tunnel.nix`：`networking.p2pTunnels.ssh.*` 选项（target/
  targetPort/privateKey/localTunnel/remoteTunnel/localIPv4/
  remoteIPv4）+ systemd `ssh-tunnel-<name>` 服务：
  `ssh -w <local>:<remote>` 建立 tun 隧道，用 `LocalCommand` 和
  远端命令配好两端地址，`Restart=always`。

## 4. 对我们仓库的启发

- 我们用 colmena/WireGuard（跨主机走 wireguard 或 tailscale），
  不需要引入；
- “SSH `-w` 建 tun + 两端配 /32 对端地址”是轻量加密链路的老
  方案，和 auto-luks 一样属于 NixOps 时代被移植的模块；
- 这个仓库说明：NixOps 1 的模块生态通过 nix-community 以插件
  形式继续存活，学结构即可。

## 5. 参考

- [nixops-encrypted-links](https://github.com/nix-community/nixops-encrypted-links)
