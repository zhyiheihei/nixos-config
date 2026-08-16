# flake-gemini 学习笔记

## 1. 是什么

`flake-gemini` 是 ehmry 维护的 **Gemini 协议软件调查 flake**：把
nixpkgs 里的 Gemini 客户端/服务器和少数本地打包的软件汇总到一个
命名空间。Nix，3 star，2023-06 已归档。用法是注册 flake registry：

```sh
nix registry add gemini github:nix-community/flake-gemini
nix run gemini#kristall
```

## 2. 内容

- overlay 本地补三个包：`gacme`（plan9port 脚本）、`html2gmi`、
  `kineto`；
- `packages` 汇总 nixpkgs 的 agate/amfora/asuka/bombadillo/castor/
  gemget/gmid/gmni/gmnisrv/kristall/lagrange/molly-brown 等；
- `nixosModules`：duckling-proxy、kineto 本地模块 +
  nixpkgs 的 molly-brown 服务模块；
- 示例 `gacme` 用 `fetchgit` 拉 sr.ht 源码，patch shebang 后安装。

## 3. 对我们仓库的启发

- 我们不跑 Gemini，不引入；
- 它代表 flakes 早期“包集注册表”用法：一个 flake 汇总一个小生态
  的所有包，后来逐渐被更规范的包集（overlay 或 nixpkgs 本身）
  取代而归档；
- 和 nixos-landscape 一样属于“生态地图”类仓库，学结构即可。

## 4. 参考

- [flake-gemini](https://github.com/nix-community/flake-gemini)
