# nix4nvchad 学习笔记

## 1. 是什么

`nix4nvchad` 用 Nix flakes 声明式安装和配置
[NvChad](https://nvchad.com/)（快速 Neovim 配置框架）。GPL-3.0，
维护者 MOIS3Y / bot-wxt1221，146 star。它把 LSP/格式化工具隔离在
NvChad wrapper 的 PATH 里，不污染系统环境。

## 2. 使用

- Home Manager：

```nix
{
  imports = [ nix4nvchad.homeManagerModules.default ];
  programs.nvchad.enable = true;
}
```

- 独立运行：`nix run github:nix-community/nix4nvchad`；
- 模块选项：`extraPackages`、`neovim`、`extraPlugins`、
  `extraConfig`、`chadrcConfig`、`gcc`、`lazy-lock`、`backup`、
  `hm-activation`。

## 3. 实现

- flake pin `github:NvChad/starter` 作为配置起点，包名 `nvchad`，
  checks = packages；
- `nvchad.nix` 把 starter 复制到 `$out/config`，用 `writeText`
  注入 extraConfig / plugins / chadrc / lazy-lock，再 `wrapProgram`
  把 `extraPackages + nodejs + lua-language-server + ripgrep +
  tree-sitter + git` 等放进 wrapper PATH；
- `bin/nvchad.sh` 首次运行时把 config 复制到 `~/.config/nvim`
  （已有目录先备份为 `nvim_<timestamp>.bak`）；
- Home Manager module 每代激活时复制配置到 `~/.config/nvim`，
  并断言不能和 `programs.neovim.enable` 同时开启；
- Intel macOS（x86_64-darwin）因 nixpkgs 停止支持而不再官方支持。

## 4. CI

- 只有 `docs.yml`：mdbook 文档构建并部署 GitHub Pages；
- 构建验证走 flake checks（`checks = packages`）。

## 5. 对我们仓库的启发

- 我们不用 Neovim/NvChad，不引入；
- 和 [nixvim](https://github.com/nix-community/nixvim) 相比：nixvim 是完整配置框架，
  nix4nvchad 保留 NvChad 官方 starter 并只做 Nix 包装；
- 值得借鉴“依赖隔离进 wrapper PATH + 首次运行初始化配置”的
  打包模式。

## 6. 参考

- [nix4nvchad](https://github.com/nix-community/nix4nvchad)
- [NvChad](https://nvchad.com)
