# NixOS switch 后无法登录的回滚与救援

本文记录 `nixos-rebuild switch --flake .#ml-2700u -L` 后机器无法登录时的处理顺序。

典型现象：

```text
ssh: connect to host 192.168.3.237 port 22: Connection refused
```

或者本地 root / lantian 密码都失效。

先记住两点：

- `Connection refused` 不是密钥错误，而是目标端口没有 sshd 监听。
- NixOS 每次 switch 都会保留上一代 generation，通常可以回滚。

## 1. 先确认是不是 SSH 端口变了

这个项目的硬化配置默认把 SSH 放到 `2222`，不是 `22`：

```nix
services.openssh.ports = [ 2222 ];
```

所以先从 Mac 测：

```bash
ssh -A -p 2222 lantian@192.168.3.237
ssh -A -p 2222 root@192.168.3.237
```

如果 `2222` 能进，机器没坏，只是端口变了。

如果 `2222` 还是：

```text
Connection refused
```

再进入下面的回滚流程。

## 2. 首选：从启动菜单选上一代 generation

重启 NixOS 机器。

在启动菜单里选择上一代 NixOS generation，不要选最新那一项。

如果看不到启动菜单，开机时尝试按：

```text
Esc
```

或：

```text
Shift
```

进入上一代后，如果能登录，执行：

```bash
sudo nixos-rebuild switch --rollback
```

如果没有 sudo，但能进 root：

```bash
nixos-rebuild switch --rollback
```

这个命令会把当前系统切回上一代可用配置。

## 3. 如果上一代也进不去：用 NixOS 安装 U 盘救援

用 NixOS 安装 U 盘启动，进入 live 环境。

切 root：

```bash
sudo -i
```

查看磁盘：

```bash
lsblk
```

以 `ml-2700u` 之前的分区为例：

```text
/dev/sda2  -> /
/dev/sda1  -> /boot
```

挂载：

```bash
mount /dev/sda2 /mnt
mount /dev/sda1 /mnt/boot
```

进入系统：

```bash
nixos-enter --root /mnt
```

现在你已经在坏掉的系统里，但拥有 root 权限。

## 4. 在救援环境里临时打开入口

编辑配置：

```bash
cd /etc/nixos
nano hosts/ml-2700u/configuration.nix
```

临时加入：

```nix
{
  services.openssh.enable = true;
  services.openssh.ports = lib.mkForce [ 22 2222 ];

  users.mutableUsers = lib.mkForce true;

  users.users.root.openssh.authorizedKeys.keys = [
    "你的 Mac 公钥"
  ];

  users.users.lantian.openssh.authorizedKeys.keys = [
    "你的 Mac 公钥"
  ];

  services.openssh.settings = {
    PasswordAuthentication = lib.mkOverride 40 true;
    PermitRootLogin = lib.mkOverride 40 "yes";
  };
}
```

Mac 公钥查看：

```bash
cat ~/.ssh/id_ed25519.pub
```

注意：这里是救援配置，目的是先把门打开。等能稳定登录后，再收紧安全策略。

## 5. 修复密码锁定问题

本项目的用户密码来自 secrets：

```text
local-secrets/glauth-users.nix
```

如果里面是：

```nix
passBcrypt = "*";
```

就表示密码锁定。root 和 lantian 都会密码不可登录。

正确做法是生成 bcrypt hash：

```bash
mkpasswd -m bcrypt
```

如果 live 环境没有 `mkpasswd`，可以先只靠 SSH key 救回来，稍后再生成密码 hash。

把 hash 写进 secrets 仓库的：

```nix
{
  lantian = {
    passBcrypt = "$2b$...";
    mail = "你的邮箱";
  };
}
```

然后提交并更新 `secrets` input。

## 6. 在救援环境里重新构建

在 `nixos-enter` 里执行：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild switch --flake .#ml-2700u -L
```

如果你已经有强机器作为 substituter：

```bash
nixos-rebuild switch --flake .#ml-2700u -L \
  --option substituters "https://cache.nixos.org ssh-ng://root@192.168.3.176" \
  --option require-sigs false
```

完成后退出并重启：

```bash
exit
reboot
```

## 7. 重启后验证

从 Mac 测：

```bash
ssh -A lantian@192.168.3.237
ssh -A -p 2222 lantian@192.168.3.237
```

至少应该有一个端口能登录。

登录后检查 sshd：

```bash
systemctl status sshd
ss -lntp | grep ssh
```

## 8. 这次为什么会锁门

这套配置里有几个默认行为：

1. SSH 默认监听 `2222`，不是 `22`。
2. `users.mutableUsers = false`，用户由 Nix 配置完全接管。
3. root 和 lantian 的密码来自 `glauth-users.nix`。
4. 如果 `passBcrypt = "*"`，密码就是锁定状态。
5. SSH 密钥来自 `ssh/lantian.nix`，不是手工写的 `~/.ssh/authorized_keys`。
6. OpenSSH host key 默认放在 `/nix/persistent/etc/ssh/...`，如果持久化目录没有准备好，sshd 可能启动失败。

所以救援后的长期修复方向是：

- 给 `lantian` 设置真实 bcrypt 密码，或者明确只用 SSH key。
- 给 `ml-2700u` 保留一个救援 SSH 入口，例如 `[ 22 2222 ]`。
- 确保 `ssh/lantian.nix` 里有你的 Mac 公钥。
- 确保 `/nix/persistent/etc/ssh/` 下 host key 存在，或为 `ml-2700u` 改回默认 host key 路径。
