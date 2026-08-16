# nixvim 学习笔记

## 1. 是什么

`nixvim` 是用 **Nix modules 配置 Neovim** 的框架（MIT，2903
star）。它把 Neovim 插件、键位、options、colorscheme、LSP 等全部
声明成 Nix 选项，构建时生成一个优化过的 Lua `init.lua` 和完整的
`nvim` 可执行包。

## 2. 使用方式

支持四种入口：

- Home Manager module：`nixvim.homeModules.nixvim`；
- NixOS module：`nixvim.nixosModules.nixvim`；
- nix-darwin module：`nixvim.nixDarwinModules.nixvim`；
- standalone：`nixvim.lib.evalNixvim` 直接求值出 package 和 test。

```nix
programs.nixvim = {
  enable = true;
  colorschemes.catppuccin.enable = true;
  plugins.lualine.enable = true;
};
```

因为输出是 Lua，配置加载比“Nix 生成 vimrc + 再解析”快；所有模块
默认关闭，只有显式 enable 的才进最终配置。

## 3. 设计特点

- 每个插件模块通常有 `settings`，接受任意 Nix attrset 并转成 Lua
  table 传给 plugin 的 setup；
- `extraConfigLua` / `extraConfigLuaPre` / `extraConfigLuaPost`
  提供原生 Lua 逃生口；
- `__raw` 类型可以把任意 Lua 代码塞进普通 option 值；
- `makeNixvim` 可独立求值，`configuration.config.build.test` 提供
  一个测试 derivation，适合放进 flake checks；
- 提供 flake template 快速初始化。

## 4. CI 与维护

- `main` 面向 nixpkgs-unstable，稳定 NixOS 用 `nixos-26.05` 分支；
- 大量真实用户配置在文档里作为示例；Matrix 和 Discussions 活跃；
- flake 用 flake-parts 组织，nix-community cachix 提供构建缓存。

## 5. 对我们仓库的启发

我们仓库目前用 Home Manager 管理 Neovim，但不依赖 nixvim：

- 如果未来想要“声明式插件 + 开箱即用默认”，nixvim 比手写
  `programs.neovim` + vimrc 更完整；
- 它的“任何 attrset 转 Lua table + raw 逃生口”设计，也适合其他
  编辑器/工具配置生成；
- 需要和 Home Manager 的 `programs.neovim` 选项做取舍，避免两套
  init 互相覆盖。

## 6. 参考

- [nixvim](https://github.com/nix-community/nixvim)
- [nixvim 文档](https://nix-community.github.io/nixvim/)
