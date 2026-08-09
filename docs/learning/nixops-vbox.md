# nixops-vbox 学习笔记

## 1. 是什么

`nixops-vbox` 是 NixOps 的 VirtualBox 后端插件（Amine Chikhaoui，
LGPL-3.0，24 star，Python，2023-08 后停更）：让
`deployment.targetEnv = "virtualbox"` 的机器在本地 VirtualBox 里
创建/启动/销毁。

和 nixops-libvirtd 的 libvirt-python 不同，这个后端主要直接调
`VBoxManage` CLI。

## 2. Nix 侧选项

`deployment.virtualbox.*`：

- `vmFlags`（任意 modifyvm 参数）、`vcpu`、`memorySize`、`headless`；
- `disks`：每个磁盘有 `port`（SATA）、`size`、`baseImage`（克隆
  源）；`disk1` 默认用 nixos.org 的 virtualbox-nixops 预构建
  vmdk（16.09–19.09 钉死 url+sha256），`runCommand` 里 `xz -d`
  解压；
- `sharedFolders`：hostPath/readOnly；有共享目录时 initrd 加
  `vboxsf` 和 mount.vboxsf。

实现还固定：`nixpkgs.system = "x86_64-linux"`、
`hasFastConnection = true`、dhcpcd `restartIfChanged = false`
（VirtualBox DHCP 不持久，重启可能换 IP）。

## 3. Guest 侧：guest property 传密钥

`virtualbox-image-nixops.nix` 导入 nixpkgs 的 virtualbox-image
模块，并加一个 systemd oneshot：

- 用 `VBoxControl guestproperty get
  /VirtualBox/GuestInfo/Charon/ClientPublicKey` 拿 NixOps 客户端
  公钥，写到 `/root/.vbox-nixops-client-key`；
- 首次启动时用 guest property 里的私钥生成
  `/etc/ssh/ssh_host_ed25519_key`；
- openssh `authorizedKeysFiles` 指向该 key 文件，实现免密部署。

## 4. Python 后端

`backends/virtualbox.py`：

- `VirtualBoxState`：状态全部 `attr_property` 持久化；
- `create`：检查 `VBoxManage`，建 VM、SATA 控制器、克隆/新建磁盘、
  NAT + 端口转发、guest property 注入公钥、`modifyvm` 应用
  vmFlags/vcpu/内存/headless，最后 `startvm`；
- `destroy`：`controlvm poweroff`（忽略失败）→ `unregistervm
  --delete`；
- SSH 用生成的 client key，host key 记录进 known_hosts。

## 5. 打包与 CI

- `default.nix`：poetry2nix `mkPoetryApplication`（给 git 依赖
  nixops 补 poetry buildInput）；`release.nix` 是老的 python2
  `buildPythonApplication` 遗留；
- poetry entry point 把 `vbox` 注册进 NixOps；`plugin.py` 提供
  nixexprs（选项 + config_exporters）和 backend；
- CI：black / mypy / flake8 / Nix 文件解析四 job（与
  nixops-libvirtd 同款）；
- 测试：`tests/functional/single_machine_vbox_base.nix`；示例：
  trivial、apache、mediawiki、容器。

## 6. 对我们仓库的启发

- 我们不用 VirtualBox，不引入；
- 与前两个 NixOps 后端（libvirtd/GCE）一起看，可总结插件结构：
  Nix options + config_exporters + Python MachineState + poetry
  plugin 注册；
- “guest property 传密钥”在本地 VM 部署里比云 metadata 更轻，
  是免 `ssh-copy-id` 的好技巧。

## 7. 参考

- [nixops-vbox](https://github.com/nix-community/nixops-vbox)
