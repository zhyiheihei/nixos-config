# nix-community 组织仓库全景

`nix-community` 是一个社区组织，不是单一作者。仓库清单约 214 个，其中约 181 个
未归档；每个仓库有独立 maintainer。NUR 只是其中一个仓库。

## 大致分类

- 包管理 / NUR：`NUR`、`nur-packages-template`、`nur-combined`、
  `nur-update`、`nur-search`、`nixpkgs`、`nixpkgs-update`、`nix-init`、
  `nix-index`
- NixOS 系统层：`nixos-anywhere`、`disko`、`colmena`、`nixos-generators`、
  `srvos`、`impermanence`、`lanzaboote`、`nixos-facter`、`NixOS-WSL`
- 语言打包转换器：`dream2nix`、`poetry2nix`、`crate2nix`、`naersk`、
  `pip2nix`、`bundix`、`npmlock2nix`、`pnpm2nix`
- 桌面 / 配置：`home-manager`、`nixvim`、`stylix`、`plasma-manager`、
  `emacs-overlay`、`neovim-nightly-overlay`
- 工具 / 基础设施：`nixd`、`nixdoc`、`rnix-parser`、`flake-compat`、
  `flakelight`、`lorri`、`infra`、`vulnix`

## 学习顺序建议

1. 先看 NUR 生态链，理解“个人包仓库”如何融入社区；
2. 再看系统层，理解 NixOS 主机怎么安装、部署、运维；
3. 再看组织自运维，理解一套完整 NixOS 基础设施的形态；
4. 最后看语言打包和开发工具链，学会自己造包、维护包。
