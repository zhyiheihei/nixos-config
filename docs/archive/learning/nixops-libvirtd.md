# nixops-libvirtd 学习笔记

## 1. 是什么

`nixops-libvirtd` 是 NixOps 的 libvirt/QEMU 后端插件：让
`deployment.targetEnv = "libvirtd"` 的机器由 NixOps 创建/启动/部署。
维护者 AmineChikhaoui，38 star，LGPL-3.0，Python + Nix 混合仓库，
2024-03 还有维护活动。

## 2. 使用方式

宿主机（仅支持 NixOS）先启用 libvirtd：

```nix
virtualisation.libvirtd.enable = true;
users.extraUsers.myuser.extraGroups = [ "libvirtd" ];
networking.firewall.checkReversePath = false;
```

再建好存储池，然后：

```sh
nixops create -d example-libvirtd examples/trivial-virtd.nix
nixops deploy -d example-libvirtd
nixops ssh -d example-libvirtd machine
```

## 3. Nix 侧：deployment.libvirtd 选项

`nixops_virtd/nix/libvirtd.nix` 定义全部选项：

- `URI`（默认 `qemu:///system`）、`storagePool`、`networks`；
- 硬件：`vcpu`、`memorySize`、`headless`、`domainType`；
- 磁盘：`baseImageSize`（G）、`baseImage`（默认用
  `make-disk-image.nix` 现做 qcow2，里面塞 root 的
  `authorized_keys`，key 从环境变量 `NIXOPS_LIBVIRTD_PUBKEY` 来）；
- 自定义：`extraDevicesXML` / `extraDomainXML`（追加 libvirt domain
  XML）、`kernel` / `initrd` / `cmdline`。

实现部分固定：x86_64-linux、根分区按 `by-label/nixos` 挂载、grub
写 `/dev/sda`、开 SSH（`UseDNS no`）、`hasFastConnection = true`。

## 4. Python 后端

`backends/libvirtd.py` 用 `libvirt-python` 实现 MachineState：

- `LibvirtdDefinition`：从配置取值（vcpu/memory/networks/XML 片段）；
- `LibvirtdState`：懒连接 hypervisor，按 deployment uuid + machine
  name 命名 domain（`nixops-<uuid>-<name>`）；
- `create`：生成随机 MAC、创建 SSH key pair、在存储池里建磁盘卷、
  组装 domain XML 后 `defineXML`（持久 domain），再启动；
- 状态全部通过 `nixops.util.attr_property` 存进 NixOps state；
- SSH flags 加 `StrictHostKeyChecking=accept-new` 和生成的私钥；
- `get_console_output` 走 `virsh console`。

插件注册：`plugin.py` 的 hookimpl 返回
`NixopsLibvirtdPlugin`（`nixexprs` 提供 `nix/default.nix` 的 options
+ config_exporters，`load` 加载 backend）。

## 5. 打包与 CI

- `default.nix` / `env.nix`：poetry2nix `mkPoetryApplication` /
  `mkPoetryEnv` + overrides；
- `pyproject.toml`：依赖 nixops（git）+ libvirt-python，通过
  poetry plugin 入口把 `virtd` 注册进 NixOps；
- `release.nix` 是老式 python2 `buildPythonApplication` 打包，属于
  历史遗留；
- GitHub Actions：black / mypy / flake8 / Nix 文件解析四个 job，
  都先 `nix-shell --run true` 预热环境。

## 6. 对我们仓库的启发

- 我们部署用 colmena，不用 NixOps，不引入；
- “NixOS module 定义选项 + Python 后端实现 + 插件注册”是 NixOps
  后端插件的标准三层结构，若以后要写部署工具插件可参考；
- `make-disk-image.nix` 预生成带 SSH key 的 qcow2 是虚拟机镜像
  引导的标准做法，和我们 nixos-images / 装机流程的思路一致。

## 7. 参考

- [nixops-libvirtd](https://github.com/nix-community/nixops-libvirtd)
- [NixOps](https://github.com/NixOS/nixops)
