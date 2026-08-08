# nixago 学习笔记

## 1. 是什么

`nixago` 是 flake 库，用 Nix 表达式作为数据源生成配置文件。MIT 协议，
作者 jmgilman，版本 3.0.0，153 star。产物放 Nix store，并提供 shell
hook 链接到项目目录。

## 2. 用法

```nix
nixago.lib.make {
  inherit data;
  output = "config.json";
  format = "json";   # 可选，匹配扩展名时可省
  engine = nixago.engines.nix { }; # 默认引擎
}
```

返回：

- `configFile`：构建配置文件的 derivation；
- `shellHook`：进入 devShell 时把文件链接到 `$PRJ_ROOT/{output}`
  （未设置 `$PRJ_ROOT` 时链接到当前目录）。

多个配置可以用 `lib.makeAll configs` 合并成一个 shellHook。

## 3. 引擎与模块

- `engines/nix.nix`：用 nixpkgs `pkgs.formats` 输出 json / toml /
  yaml / ini；
- `engines/cue.nix`：用 CUE 模板做更复杂的校验/转换；
- `modules/request.nix`：定义 `make` 的全部选项；
- hooks 支持 link/copy 两种模式，带 ANSI 输出和调试信息。

## 4. 扩展与自举

- 配套 [nixago-extensions](https://github.com/nix-community/nixago-extensions)
  提供 ghsettings、conform、just、lefthook、prettier 等常见工具的
  配置生成；
- 仓库自己的 `.config.nix` 就用这些扩展管理 GitHub labels、
  conform、justfile、lefthook、prettier 配置（dogfood）；
- devshell 里 `shellHook = (lib.makeAll configs).shellHook`，进入
  shell 即生成并链接所有配置文件。

## 5. CI 与测试

- `nix flake check` 跑测试，tests 下有 nix 引擎的
  json/toml/yaml/ini 期望输出和 CUE 测试；
- `ci.yml`：`nix develop -c just check`；
- `docs.yml`：mdbook 文档部署 GitHub Pages；
- `release.yml`：release-please 自动发版。

## 6. 对我们仓库的启发

- 我们目前配置大多手写 Nix/服务文件，不需要引入；
- 如果以后想让“仓库元数据、lint 配置、服务配置”统一从 Nix 数据
  生成，nixago + extensions 是现成模式；
- 它的“配置即 derivation + shell hook 链接”思路和 devshell 很搭，
  适合工具链仓库。

## 7. 参考

- [nixago](https://github.com/nix-community/nixago)
- [nixago docs](https://nix-community.github.io/nixago/)
- [nixago-extensions](https://github.com/nix-community/nixago-extensions)
