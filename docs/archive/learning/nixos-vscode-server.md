# nixos-vscode-server 学习笔记

## 1. 是什么

`nixos-vscode-server` 提供 NixOS 上的 VS Code Server 支持，解决
VS Code 自带 NodeJS 在 NixOS 上因硬编码路径无法运行的问题。

## 2. 原理

VS Code Server 默认带一份 NodeJS，但在 NixOS 上不可用。本项目：

- 自动把内置 NodeJS 替换为 NixOS 可用的 symlink；
- 提供 `enableFHS` 让扩展二进制在 FHS 环境运行；
- 自动 patch ELF 二进制；
- 通过 systemd user service 监视安装路径。

## 3. 主要选项

```nix
services.vscode-server = {
  enable = true;
  enableFHS = true;
  nodejsPackage = pkgs.nodejs_22;
  extraRuntimeDependencies = pkgs: [ pkgs.curl ];
  installPath = "$HOME/.vscode-server";
};
```

## 4. 对我们仓库的启发

如果以后在 NixOS 主机上跑远程开发，这个模块比手工 patch 更省事。
它展示了“修补第三方自带的运行时/二进制”这一类 NixOS 适配模式。

## 5. 参考

- [nixos-vscode-server](https://github.com/nix-community/nixos-vscode-server)
