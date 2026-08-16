# nixos-generators 学习笔记

## 1. 是什么

`nixos-generators` 是 Lassulus 维护的 **NixOS 镜像生成器集合**：
一份 NixOS 配置生成多种格式镜像（ISO、qcow2、raw、云镜像、
Vagrant、Docker、kexec、SD 卡等）。MIT，2401 star，**已归档**：
README 说明 NixOS 25.05 起功能已上游进 nixpkgs，由
`nixos-rebuild build-image` 取代。

## 2. 用法

```sh
# 旧 CLI
nixos-generate -f qcow -c ./configuration.nix

# 旧 flake 函数
nixos-generators.nixosGenerate {
  system = "x86_64-linux";
  modules = [ ./configuration.nix ];
  format = "vmware";
}

# 新方式（nixpkgs）
nixos-rebuild build-image --image-variant iso --flake .#myhost
```

## 3. 实现

- `formats/`：30+ 个格式模块（amazon/azure/gce/do/openstack/
  hyperv/iso/qcow/raw/kexec/lxc/lxd/proxmox/sd-*/vagrant/
  virtualbox/vmware/vm 等），各自声明 `system.build.*` 产物；
- `flake.nix` 导出 `nixosModules`（每个格式一个模块 + 内部
  format options）和 `nixosGenerate`（组合 nixosSystem +
  formatModule，支持 customFormats）；
- `lib.nix`：处理 nixpkgs 里 `system.build` 从惰性 attrset 变
  submodule 的兼容（mkForce 判断）；
- `nixos-generate`：非 flake CLI。

## 4. 对我们仓库的启发

- 我们已经在用其继承者（nixos-rebuild build-image / 我们的
  nixos-images 类镜像），不需要引入旧版；
- “一份配置多格式输出”是镜像生成的标准模型，格式与构建逻辑
  分离（每格式一个模块）值得 zhyi-packages/镜像工具借鉴；
- 它被上游化后归档，是我们反复看到的生命周期。

## 5. 参考

- [nixos-generators](https://github.com/nix-community/nixos-generators)
