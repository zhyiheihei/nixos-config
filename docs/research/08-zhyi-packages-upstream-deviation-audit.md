# 调研文档 08：zhyi-packages 与 xddxdd/nur-packages 的偏移审计

> 日期：2026-08-12。对照对象：`xddxdd/nur-packages`，HEAD
> `e9d7784b9963f20734f9b3b91304595585a654f7`；`zhyi-packages` HEAD
> `46ff953`，工作树干净，与 origin/main 对齐。

## 总体

`diff -rq /tmp/xddxdd-nur-packages /Users/molishanguang/my-project/nixos/zhyi-packages --exclude .git`：

| 指标 | 数量 |
| --- | ---: |
| 差异条目 | 250 |
| 共有文件有差异 | 21 |
| zhyi-packages 独有 | 22（全部为 `pkgs/` 下包目录） |
| 上游独有 | 207 |

## 允许的偏移（自用化）

- 包命名空间：`nur-zhyiheihei` 代替 `nur-xddxdd`。
- NUR 注册：`repos.json` 指向 `zhyiheihei/zhyi-packages`。
- 缓存：`helpers/meta.nix` 只保留 `https://attic.zhyi.xin/lantian`，去掉上游
  Cachix。
- README、AGENTS、LICENSE、`.vscode` 等为自用版本；README 仍由
  `pkgs/_meta/readme` 生成，未手改。
- GitHub Actions bot 身份与仓库名改为 `zhyiheihei`。

## 结构偏移

- 本地保留：flake-parts、devshell、treefmt、pre-commit、commands、
  `pkgs/default.nix` 分组、`_sources` 与 nvfetcher 体系。
- 本地未移植上游能力：`modules/`、`auto-colmena-hive-v0*.nix`、
  `modules-test-nixos-config.nix`、`pkgs/lantian-customized`、
  `pkgs/kernel-modules`、`pkgs/nvidia-grid`、`pkgs/lantian-linux-cachyos`
  等。这些属于作者 NixOS 基础设施，不是包补充仓库的必需部分。
- `flake.nix` 去掉 colmena/NixOS modules/Cuda/pinned overlay 分支，只保留
  packages/overlay；nixpkgs 固定到 `f13ff45afd1bb73e640eaa08a7066dbed07e3238`，
  避免 `update` 刷新来源时被 nixpkgs 漂移破坏 `pnpm_9` 包构建。

## 工作流偏移

- `auto-update.yml` 与上游行为一致：`nix run .#update` +
  `nix run .#update-hashes`，未改成 `update-sources`；只有步骤名与 bot
  身份不同。
- `build.yml` 保留上游 `nix run .#nur-check` 与
  `tools/check_package_meta.py`，新增 Attic `push-cache` job（上游没有）；
  `update-nur` 指向 `zhyiheihei`。
- auto-update 使用 `GITHUB_TOKEN` 提交，GitHub 不会为自动提交 `46ff953`
  再触发 build workflow，这是平台防递归行为，不是配置错误。

## 包集偏移

本地独有（自用补充，nixpkgs 未收录）：

- `pkgs/python-packages`（11 个）：aioshutil、cn2an、jieba-next、
  pinyin2hanzi、proces、pypika-tortoise、pyromark、telegramify-markdown、
  torrentool、tortoise-orm、zhconv-rs
- `pkgs/uncategorized`（11 个）：docker-proxy、docker-proxy-hubcmdui、
  filecodebox、moviepilot、nexus-media、nexus-media-web、sublinkpro、
  sun-panel、tachidesk-server、vaults3、vertex

上游独有主要是 159 个 uncategorized 包与 32 个 python 包目录中未移植的部分，
以及 `pkgs/lantian-customized`、`pkgs/kernel-modules` 等专用目录；这些是
作者自用或与作者基础设施绑定的包，不属于本仓库职责。

## 验证状态

- 本地 `git status` 干净，`main` 与 `origin/main` 对齐。
- `Auto update packages`（run 31554881972）成功，产生提交 `46ff953`。
- `Build and populate cache`（run 31554859526，提交 `a21bb2a`）中
  `test-nur-eval` 与 `check-package-meta` 均通过；`push-cache` 仍在
  构建/上传 Attic。
- 未修改 `xddxdd` 或 `nix-community` 的上游仓库；`_sources/generated*`
  由 `nix run .#update` 自动生成。

## 结论

偏移符合仓库定位：结构沿用上游，工作流保留 `update` 本意，包集以自用补充
为主，未破坏 NUR 注册与 meta 规范。
