# pipewire-to-json 学习笔记

## 1. 是什么

`pipewire-to-json` 是 Mic92 写的小工具（C，MIT，2 star，2021-02
已归档）：把 PipeWire 的 SPA 风格配置文件转成标准 JSON。README
开头写明**已废弃**——PipeWire 上游自带同类工具
（[commit 3c9996aa](https://gitlab.freedesktop.org/pipewire/pipewire/-/commit/3c9996aa781c3cf3623547dbddad4772196ae391)）。

```sh
pipewire-to-json pipewire-config json-output
```

## 2. 实现

- `main.c`：mmap 读配置 → `pw_properties_new_string` → 递归遍历
  `spa_json`，把 object / array / float / bool / null / string
  逐层转成 json-c 对象，写出 JSON；
- 依赖 json-c + pipewire（用其 spa JSON 解析器，避免自己重写）。

## 3. 工程

- meson 构建；`default.nix` 用 nixpkgs 的 pipewire 配置目录做
  测试（`doCheck` 时转换所有 `.conf`）；
- CI：`nix-build`（当时 nixpkgs PR 未合并，先钉 revision）。

## 4. 对我们仓库的启发

- 我们音频栈用 pipewire，但转换功能上游已有，不需要引入；
- 它再次示范“小工具被上游吸收后归档”的短生命周期；
- “用生态自己的解析库而不是重新实现格式”是可靠做法，和
  eask2nix 让 Eask 自己构建 artifact 同理。

## 5. 参考

- [pipewire-to-json](https://github.com/nix-community/pipewire-to-json)
