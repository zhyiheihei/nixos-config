# vagrant-nixos-plugin 学习笔记

## 1. 是什么

`vagrant-nixos-plugin` 是一个 Vagrant 插件（Ruby gem），给 NixOS guest
增加 `:nixos` provisioner。作者 zimbatm，74 star；仓库本身是
`oxdi/vagrant-nixos` 的 fork，nix-community 下由 @zimbatm 维护，MIT
许可，最后一次发布 0.2.2（2018-07）。

Vagrant 1.6.4+ 本身只负责给 NixOS guest 写
`/etc/nixos/vagrant-{hostname,network}.nix`，并不会运行
`nixos-rebuild switch`。这个插件补上 rebuild，并提供三种配置写法。

## 2. 三种 provision 方式

```ruby
# 1. 原生 Nix 模块字符串
config.vm.provision :nixos, inline: %{
{ config, pkgs, ... }: with pkgs; {
  environment.systemPackages = [ htop ];
}
}

# 2. 外部 Nix 文件
config.vm.provision :nixos, path: "configuration.nix"

# 3. Ruby Hash 自动转 Nix（expression 模式）
config.vm.provision :nixos, expression: {
  environment: { systemPackages: [ :htop ] }
}
```

校验规则：`path` / `inline` / `expression` 三选一，不能同时给多个；
`path` 必须在本机存在。

## 3. Ruby → Nix DSL

`lib/vagrant-nixos/nix.rb` 靠给 Ruby 核心类补 `to_nix` 实现：

- `Symbol` → 裸标识符，如 `:htop` → `htop`
- `Hash` → `{ key = value; }`，key 必须是 Symbol，按键排序
- `Array` → `[ ... ]`
- `String` → 双引号字符串；含换行时用 `''...''`；
  `./` 开头原样输出
- `Integer` / `true` / `false` / `nil` → 对应 Nix 字面量
- `Nix.method_missing` 构造带点的表达式：`Nix.pkgs.postgresql93`
  渲染成 `pkgs.postgresql93`，`Nix.lib.mkForce(...)` 渲染成
  `lib.mkForce(...)`，`Nix.import(...)` 会包一层括号

expression 模式最终生成
`{config, pkgs, ...}: with pkgs; <ruby hash 转出的 nix>`。

## 4. provision 流程

`Provisioner#provision` 把选中的配置写到
`/etc/nixos/vagrant-provision.nix`（文件头注明会被插件覆盖），然后：

1. `prepare!`：扫描 guest 上 `/etc/nixos/vagrant-*.nix`，把全部 import
   收集进新生成的 `/etc/nixos/vagrant.nix`；若 Vagrantfile 没设 hostname
   或 private network，删除对应的旧文件，避免残留配置。
2. `rebuild!`：执行 `nixos-rebuild switch`（sudo）。
3. `trace` 追加 `--show-trace`；`include: true` 追加
   `-I nixos-config=/etc/nixos/vagrant.nix`；`verbose` 把构建输出实时
   显示到 UI；`NIX_PATH` 可覆盖默认路径，也写入 shellInit。
4. `write_config` 先上传到 `/tmp`，`cmp` 相同则不动，不同才 `mv`，
   减少无谓的 rebuild 触发。

约定：NixOS box 的 `configuration.nix` 必须 import
`/etc/nixos/vagrant.nix`；参考 zimbatm/nixbox 的 packer 模板。

## 5. 工程结构

- `config.rb`：provisioner 选项 + 校验
- `plugin.rb`：Vagrant plugin 2 API，注册 `config :nixos, :provisioner`
- `provisioner.rb`：核心逻辑
- `nix.rb`：Ruby → Nix DSL
- gem 依赖只有 bundler/rake（开发用）；Vagrant 本体由
  `vagrant plugin` 环境提供
- 无 GitHub Actions；构建发布走 gem 任务

## 6. 对我们仓库的启发

- 我们不用 Vagrant，不需要引入；它演示了“Vagrant 只写配置、
  由插件补 rebuild”的职责划分，和 NixOS 官方
  `vagrant-{hostname,network}.nix` 约定。
- 如果以后要写类似“临时生成 Nix 模块再交给 nixos-rebuild”的工具，
  可直接借鉴它的三选一配置、导入文件自动收集、先上传再 cmp 避免
  无谓重建这几个设计。

## 7. 参考

- [vagrant-nixos-plugin](https://github.com/nix-community/vagrant-nixos-plugin)
- 上游 fork 来源：[oxdi/vagrant-nixos](https://github.com/oxdi/vagrant-nixos)
- NixOS box 模板：[zimbatm/nixbox](https://github.com/zimbatm/nixbox)
