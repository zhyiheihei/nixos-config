# mineflake 学习笔记

## 1. 是什么

`mineflake` 是声明式 Minecraft 服务器的 Nix flake：把服务器
（Paper/Spigot/Bungee 等）、插件和配置打包成 Docker/OCI 镜像或
NixOS 服务。MIT 协议，作者 cofob，80 star，项目已标注未维护。

## 2. 用法

```nix
with pkgs; mineflake.buildMineflakeContainer {
  package = mineflake.paper;
  command = "${jre_headless}/bin/java -Xms1G -Xmx1G -jar {} nogui";
  plugins = with mineflake; [ luckperms ];
  configs = [
    (mineflake.mkMfConfig "mergeyaml" "plugins/LuckPerms/config.yml" {
      server = "vanilla_1";
    })
  ];
}
```

也有 `buildMineflakeLayeredContainer` 和
`buildMineflakeBin`（systemd/NixOS 直接跑）。

## 3. 结构

- Nix 侧：`pkgs/default.nix` 提供配置构建函数、包构建
  （`buildMineflakePackage` / `buildZipMfPackage`）、server 集
  （`servers/`）和 plugin 集（`plugins/`）；
- Rust CLI：读取 mineflake.json，把插件/配置 link 进服务器目录，
  支持 `mergeyaml` 等配置生成器、远程包下载（IPFS 网关）、
  spigot/bungee 结构；
- flake 提供 overlay 和 docker 模板。

## 4. CI

- `ci.yml`：nixpkgs-fmt、rustfmt、clippy、Windows/Linux cargo
  test+build、`nix build`；
- `main.yml`：构建所有 derivation 后用 web3.storage 上传到 IPFS，
  把 pin 列表提交到 `repo` 分支（`repo.json`）；
- `docs.yml`：mkdocs 部署 GitHub Pages。

## 5. 对我们仓库的启发

- 我们没跑 Minecraft，且项目未维护，不需要引入；
- 可借鉴“配置 JSON + link 插件/配置 + 容器镜像”的分层，以及
  “构建产物固定到 IPFS”的缓存思路。

## 6. 参考

- [mineflake](https://github.com/nix-community/mineflake)
- [mineflake docs](https://mineflake.cofob.dev/)
