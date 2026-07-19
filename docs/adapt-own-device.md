# 适配自己的 NixOS 设备

这是第一次阅读本仓库时的入口说明；真正的安装与接入约束以
[新主机接入规范](./new-host-standard.md) 和根目录 `AGENTS.md` 为准。

## 先确认三件事

1. 新设备属于物理 client、server VM，还是 PVE 宿主。三类设备的磁盘和引导
   布局不能混用。
2. 设备是否已拥有独立、持久化的 SSH host key。它同时是 SSH 服务器身份和 SOPS
   解密身份，不能临时生成后遗漏保存。
3. 目标是否需要加入现有网络。局域网地址、主机 index、WireGuard、ZeroTier 与
   DN42 标识都必须唯一。

## 推荐顺序

1. 阅读 `hosts/` 中角色相近的主机，以及对应的 `host.nix`、
   `configuration.nix`、`hardware-configuration.nix`。
2. 在本仓库新建 `hosts/<hostname>/`，只复制结构，不复制作者或其他机器的地址、
   磁盘 UUID、城市、密钥和网络标识。
3. 先按目标布局从安装环境安装一个可独立启动的最小系统。物理 client 使用 tmpfs
   `/`、EFI `/boot`、Btrfs `/nix`；不要从普通 ext4 根系统在线切换过去。
4. 在 secrets 仓库依照 `nixos-secrets/docs/sops-manual.md` 加入该主机的 age
   recipient，并重新加密受管文件。
5. 由 `ml-builder` 构建，先单机验证，再加入日常 Colmena 部署集合。

## 配置边界

- 本地 `nixos-config` 是唯一配置基准；远端机器仅拉取已提交版本或接收闭包。
- `hardware-configuration.nix` 必须由真实设备生成并人工复核，尤其是 `/boot`、
  `/nix`、磁盘 UUID、网卡和 initrd 模块。
- 私钥、解密后的 SOPS YAML、云 API token 不进入本仓库。个人登录私钥由 Bitwarden
  管理；服务器 host key 保存在目标机的持久目录。
- 不为首次安装引入完整服务集。先确认启动、SSH、SOPS、网络和文件系统正常，再
  逐步启用应用或网络角色。

## 最小验收

```bash
hostname
findmnt / /boot /nix
systemctl is-system-running
systemctl --failed --no-pager
systemctl is-active sshd sops-install-secrets
```

加入 WireGuard、ZeroTier 或 DN42 的机器还应按[新主机接入规范](./new-host-standard.md)
检查握手、路由与 BIRD 状态。完整部署命令见[构建与部署当前主机](./deployment.md)。
