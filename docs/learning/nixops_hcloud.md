# nixops_hcloud 学习笔记

## 1. 是什么

`nixops_hcloud` 是 NixOps 的 Hetzner Cloud 后端插件（RoGryza /
Rodrigo Gryzinski，MIT，6 star，Python，2022-08 已归档）。README
明说不活跃，推荐替代品
[lukebfox/nixops-hetznercloud](https://github.com/lukebfox/nixops-hetznercloud)。

依赖 `hcloud` Python SDK；实现范围：

- server 生命周期管理（创建/销毁/启动等；reboot/rescue 等可选
  操作未实现）；
- volume 创建、挂载；
- SSH keys 资源。

## 2. 引导方式：快照 + label

Hetzner 提供 NixOS ISO，但没法自动从 ISO 装 NixOS，所以：

1. 从 Hetzner 的 `NixOS 20.03` ISO 启动；
2. 跑 `bootstrap/nixos-install-hetzner-cloud.sh`（清盘安装
   NixOS，配置里用 `fetchHetznerKeys.nix` 从 metadata 拉 SSH
   key），重启；
3. 把引导好的 server 打成 snapshot，打上名为 `nixops` 的 label；
4. NixOps 后端从这个快照创建机器再部署。

## 3. Nix 侧与后端

- `nix/hcloud.nix`：`deployment.hcloud.*` 选项（token/context、
  server type、location、ssh keys、volumes 等）；
- `hcloud_volume.nix` / `hcloud_sshkey.nix`：资源模块；
- `backends/hcloud.py` + `resources/`：MachineState /
  ResourceState，状态 `attr_property` 持久化；
- 认证：hcloud CLI context，或 token/context 选项；
- 打包：poetry2nix `mkPoetryApplication`，插件入口 `hcloud`；
- dev 依赖 mypy/black/pylint/isort/pytest；README 承认 lint 未
  自动化、代码警告多。

## 4. 对我们仓库的启发

- 我们不用 Hetzner，不引入；
- “云厂商无官方 NixOS 镜像就手动引导一次 + snapshot”是 NixOps
  云后端的通用 bootstrap 手段（和 DigitalOcean 的 nixos-infect
  同类）；
- 和 nixops-libvirtd/gce/vbox/digitalocean（均已学）一起看，可
  完整掌握 NixOps 插件结构；它归档也说明社区常会出现“更好的
  替代插件”，学习时注意 README 的替代指引。

## 5. 参考

- [nixops_hcloud](https://github.com/nix-community/nixops_hcloud)
