# nixos-modules-contrib 学习笔记

## 1. 是什么

`nixos-modules-contrib` 是 adisbladis 做的“不太适合进 Nixpkgs 的
NixOS 模块”集合，以 NixOps 插件形式提供（LGPL-3.0，16 star，
Python + Nix，2021-01 后停更）。两个模块原本在 NixOps 1.x 里，
NixOps 2.0 移除后搬到这里继续用。

## 2. auto-luks

`deployment.autoLuks.<name>` 声明 LUKS 卷：

```nix
deployment.autoLuks.secretdisk = {
  device = "/dev/xvdf";
  passphrase = "foobar";   # 或留空由 NixOps 自动生成
  autoFormat = true;       # blkid 判断为空时 cryptsetup luksFormat
};
```

实现：每个卷生成一个 systemd oneshot
`cryptsetup-<name>`（`DefaultDependencies = false` 避免循环）：
先用 `deployment.keys` 提供的 keyfile `luksOpen`；`autoFormat`
时先 `blkid` 判断并 `luksFormat`（cipher/keySize 可配）。服务挂在
`/dev/mapper/<name>.device` 的 `wantedBy` 上，先于 mkfs 运行。

## 3. auto-raid0

`deployment.autoRaid0.<name>.devices` 声明 RAID-0（实际是 LVM
条带 LV）：

```nix
deployment.autoRaid0.bigdisk.devices = [ "/dev/xvdg" "/dev/xvdh" ];
```

oneshot `create-raid0-<name>` 按序：

1. `pvcreate`（已是 LVM2_member 跳过，非空设备拒绝并报错）；
2. `vgcreate`；
3. `lvcreate --extents 100%FREE --stripes <N>`；
4. `vgchange -ay`，最后确认 mapper 设备出现。

## 4. 工程

- `auto-luks/` / `auto-raid0/` 各是目录模块（`default.nix` +
  `__init__.py`）；
- `plugin.py` 注册 NixOps 插件；poetry entry point
  `nixos_modules_contrib`；
- nixops-gce（已学）的 pyproject 就依赖这个仓库；
- 无 CI workflows。

## 5. 对我们仓库的启发

- 我们不用 NixOps，不引入；
- auto-luks 的“systemd 设备单元 + blkid 幂等判断 + keyfile 注入”
  是云盘加密的成熟模式，和我们在 disko/主机配置里处理 LUKS 的
  思路一致；
- “被上游移除的模块搬到贡献仓库”给了我们一个启示：重构时不要
  直接删功能，可先下沉到独立仓库保持可用。

## 6. 参考

- [nixos-modules-contrib](https://github.com/nix-community/nixos-modules-contrib)
