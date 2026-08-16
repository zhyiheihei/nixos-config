# flake-firefox-nightly 学习笔记

## 1. 是什么

`flake-firefox-nightly` 提供 Firefox Nightly（以及 release/ESR/
beta/devedition）的二进制 Nix 包，版本和 hash 固定在 `latest.json`，
支持 `--pure-eval`。作者 colemickens，75 star。

## 2. 用法

```nix
environment.systemPackages = [
  inputs.firefox.packages.${pkgs.system}.firefox-nightly-bin
];
```

支持 x86_64-linux / aarch64-linux；flake 同时导出 overlay。

## 3. 更新机制

- `generate.nu`（Nushell）从 Mozilla
  `product-details.mozilla.org` 拿版本，从 `SHA512SUMS` /
  buildhub JSON 拿 hash，生成 `latest.json`；
- `update.nu`：`nix flake update` → `generate.nu` → `nix build` →
  `nix flake check` → 提交推送；
- GitHub Actions `update.yaml` 每小时跑一次，用 nscloud runner +
  Cachix。

## 4. 打包

- `package.nix` 是 nixpkgs `firefox-bin` 的精简版：autoPatchelf +
  wrapGApps，写 `policies.json`（`DisableAppUpdate = true`），
  `patchelf --no-clobber-old-sections` 处理 relrhack；
- overlay 里用 `wrapFirefox` 包装各分支；
- checks 是 NixOS VM 测试：起 X11，打开页面并截图。

## 5. 对我们仓库的启发

- 我们客户端浏览器走 nixpkgs 稳定 Firefox，不需要 Nightly；
- 它演示了“每小时自动抓上游版本 + hash → 固定 JSON → flake
  打包 + VM 冒烟测试”的完整更新流水线。

## 6. 参考

- [flake-firefox-nightly](https://github.com/nix-community/flake-firefox-nightly)
