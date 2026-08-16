# nixago-extensions 学习笔记

## 1. 是什么

`nixago-extensions` 是 jmgilman 为 [nixago](https://github.com/nix-community/nixago)
（已学）提供的“常用开发工具配置生成扩展”集合：每个扩展接受简化
输入，产出能直接喂给 `nixago.lib.make` 的配置对象。17 star，MIT，
2023-02 后基本停更。

```nix
nixago.lib.make (nixago-exts.prettier { data = { proseWrap = "always"; }; })
```

## 2. 扩展清单

- **conform**：commit / license 策略 → `.conform.yaml`；
- **ghsettings**：GitHub 仓库设置 + issue labels → `.github/settings.yml`
  （本仓库的 labels 就是自己生成的）；
- **just**：任务列表 → `justfile`；
- **lefthook**：`lefthook.yml` + `hook` 额外脚本，文件变化时自动
  `lefthook add` 各 stage；
- **pre-commit**：`.precommit-config.yaml`；
- **prettier**：默认生成 `.prettierrc.json`，`type = "ignore"` 时
  生成 `.prettierignore`。

## 3. 实现模式

- `extensions/default.nix`：`readDir` 自动发现目录，逐个 import
  （扩展名即属性名）；
- 每个扩展返回
  `{ data; format; output; engine = engines.cue { files = [模板]; }; }`
  ——数据用 CUE 模板渲染，输出到固定文件名；
- 简化输入（如 conform 的 `commit/labels`）在扩展内部展开成
  完整结构，用户不用记 Nixago 的细节；
- flake 用 nixago 的 `rename-config-data` 分支；devShell 自带
  conform/cue/just/lefthook/alejandra/prettier/typos/mdbook。

## 4. 测试与 CI

- `tests/common.nix`：每个测试用 `make (exts.<name> input)` 生成
  文件，再 `cmp` 与 `expected.*` 对比；
- `tests/default.nix`：自动发现测试目录，skipTests 可排除；
- CI：`just check`（alejandra / prettier / typos / `nix flake
  check`）；`docs.yml` 构建 mdbook 部署 gh-pages；
- 仓库“吃自己的狗粮”：`.config.nix` 用扩展生成自身全部开发配置。

## 5. 对我们仓库的启发

- 我们不用 nixago，不引入；
- “简化输入 → CUE 模板 → 固定输出文件名”的扩展架构，把
  “生成配置”做成了可组合的小插件，值得 zhyi-packages 或文档
  工具做模板系统时参考；
- 自动发现目录（`readDir`）生成属性集 + 生成结果与期望文件
  `cmp` 对比，是轻量、可靠的测试套路。

## 6. 参考

- [nixago-extensions](https://github.com/nix-community/nixago-extensions)
- [nixago](https://github.com/nix-community/nixago)
