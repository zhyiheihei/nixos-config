# terraform-nixos 学习笔记

## 1. 是什么

`terraform-nixos` 提供一组 Terraform modules，用于在云平台部署 NixOS。
组织描述为 “A set of Terraform modules that are designed to deploy NixOS”。

## 2. 典型思路

- Terraform 负责创建云资源（VM、网络、存储）；
- 通过 Terraform 在机器上安装/引导 NixOS；
- 再让机器加载 NixOS 配置，进入正常 NixOS 生命周期。

## 3. 与我们的关系

- `nix-community/infra` 使用 Terraform 管理部分云资源；
- 我们对已有 NixOS 机器的日常运维使用 colmena；
- 两者互补：Terraform 管“创建/销毁”，colmena 管“构建/切换”。

## 4. 状态说明

当前网络抖动，README 尚未拉取完整，本笔记先记录组织描述和定位，
后续网络恢复后补充具体 module 用法。

## 5. 参考

- [terraform-nixos](https://github.com/nix-community/terraform-nixos)
