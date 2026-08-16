# steam-fetcher 学习笔记

## 1. 是什么

`steam-fetcher`（nix-steam-fetcher）提供 `fetchSteam`：一个包装
[DepotDownloader](https://github.com/SteamRE/DepotDownloader) 的
Nix fetcher，用来下载 Steam depot。作者 aidalgol，74 star，目标场景
是“通过 Steam 分发的游戏服务器”的 NixOS module。

## 2. fetchSteam

```nix
src = fetchSteam {
  inherit name;
  appId = "xyz";
  depotId = "xyz";
  manifestId = "xyz";
  # branch = "beta_name";
  # fileList = ["filename" "regex:(or|a|regex)"];
  hash = "sha256-...";
};
```

实现是 recursive fixed-output derivation：用 DepotDownloader
`-app/-depot/-manifest` 下载到 `$out`，删掉 `.DepotDownloader`
元数据目录；`outputHash` 锁定内容。

## 3. steamworks-sdk-redist

- 用 `fetchSteam` 下载 Steamworks SDK Redist（app 1007）；
- 只安装对应平台的 `steamclient.so`（i686/x86_64-linux），
  autoPatchelf + FHS 环境使用；
- meta：`unfreeRedistributable`、`binaryNativeCode`。

## 4. 配套模式

README 给出完整示例：游戏服务器包（unwrapped）+ FHS 环境 wrapper +
NixOS module（overlay 注入 + systemd 服务 + 防火墙端口），
`allowUnfreePredicate` 只放行需要的包。

## 5. CI

- `cicd.yml`：用 Lix 安装器跑 `just shellcheck` / `shfmt` /
  `nixfmt`，并构建 steamworks-sdk-redist。

## 6. 对我们仓库的启发

- 我们没跑 Steam 服务器，不需要引入；
- “固定 manifest + fixed-output fetcher + FHS wrapper + NixOS
  module”是 Steam 游戏服务器的标准打包模板，以后要用可以直接参考。

## 7. 参考

- [steam-fetcher](https://github.com/nix-community/steam-fetcher)
- [DepotDownloader](https://github.com/SteamRE/DepotDownloader)
