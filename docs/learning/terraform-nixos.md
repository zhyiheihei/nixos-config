# terraform-nixos 学习笔记

## 1. 是什么

`terraform-nixos` 提供一组 Terraform modules，用于在云平台部署 NixOS。
组织描述为 “A set of Terraform modules that are designed to deploy NixOS”。

## 2. 典型思路

- Terraform 负责创建云资源（VM、网络、存储）；
- 通过 Terraform 在机器上安装/引导 NixOS；
- 再让机器加载 NixOS 配置，进入正常 NixOS 生命周期。

## 3. 提供的模块

- `deploy_nixos`：把 NixOS 配置部署到已运行的 NixOS 机器；
- `google_image_nixos`：把官方 GCE 镜像导入 Google Cloud；
- `google_image_nixos_custom`：构建自定义 GCE 镜像并部署。

使用方式：

```hcl
module "deploy_nixos" {
  source = "github.com/tweag/terraform-nixos//deploy_nixos?ref=COMMIT"
  # module-specific fields
}
```

注意 `//` 分隔 GitHub 仓库和子目录，`?ref=` 固定版本。

## 3. 与我们的关系

- `nix-community/infra` 使用 Terraform 管理部分云资源；
- 我们对已有 NixOS 机器的日常运维使用 colmena；
- 两者互补：Terraform 管“创建/销毁”，colmena 管“构建/切换”。

## 4. 与 NixOps 的对比

- NixOps 适合个人部署，但云 API 覆盖面有限；
- Terraform 是行业标准，state 可以同步/锁定，适合团队；
- terraform-nixos 用 Terraform 管资源，用 Nix 管配置，灵活但需要学两套语言。

## 5. 参考

- [terraform-nixos](https://github.com/nix-community/terraform-nixos)
