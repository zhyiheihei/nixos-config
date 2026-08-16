# patsh 学习笔记

## 1. 是什么

`patsh` 是 figsoda 写的 Rust 命令行工具：把 shell 脚本里出现的命令
名 patch 成 Nix store 里的绝对路径，灵感来自
[resholve](https://github.com/abathur/resholve)。56 star，MPL-2.0，
发布在 crates.io（当前 0.2.1）。

典型用途：给要打进 Nix derivation 的 shell 脚本做“路径固化”，
让脚本不依赖运行时 PATH 就能找到真实命令（在 pure build 里更稳）。

```sh
nix run github:nix-community/patsh -- -f script.sh
```

## 2. CLI

```text
patsh [OPTIONS] <INPUT> [OUTPUT]

-b, --bash <COMMAND>    列出 bash builtin 用的命令 [default: bash]
-f, --force             允许覆盖已存在的输出文件
-p, --path <PATH>       覆盖 PATH 用于解析命令
-s, --store-dir <PATH>  Nix store 路径 [default: /nix/store]
```

默认输出到输入文件本身，但要求 `--force`；否则用 `create_new` 防止
意外覆盖。

## 3. 实现

`src/parse.rs` + `src/patch.rs`，核心流程：

1. 用 `tree-sitter-bash` 解析脚本；
2. 遍历 AST 的 `command_name` 节点；
3. `parse_command` 识别特殊 wrapper：
   - `command` / `exec` / `type`：跳过它们的选项，继续解析后面真正
     的命令；
   - `sudo` / `doas`：跳过其选项和用户名参数，patch 内部命令；
   - 普通命令：直接记录；
4. `patch_node` 对每个命令名：
   - 已在 store 内的绝对路径跳过；
   - 解析字面量（`raw_string` / `string` / `word`，含转义处理）；
   - 在 PATH 里找可执行文件，跟随符号链接；
   - 只有当解析结果落在 `store_dir` 内才替换；
   - builtin 命令（用 `bash -c enable` 枚举）默认不 patch；
5. `patch` 按字节区间重写输出，路径用 `shell-escape` 转义，
   非 UTF-8 时退化为单引号包裹。

## 4. 测试

`tests/fixtures/` 有三组用例（basic/escape/exec），每个
`*-expected.sh` 对应输入；测试用 `assert_cmd` 跑二进制 + 
`expect-test` 逐字节比对。`package.nix` 的 `postPatch` 把预期文件里
的 `@coreutils@` / `@cc@` / `@test_support@` 替换成真实 store 路径，
因此断言的是“解析到 Nix store 内路径”的行为。special fixture 里
还有 `foo$`、以双引号加反引号结尾的名字这类难处理文件名，
专门测引号转义。

## 5. Flake 与 CI

- flake：flake-parts + fenix（提供 rustfmt）+ treefmt-nix，格式化
  工具含 actionlint、deadnix、nixfmt、oxfmt、rustfmt、statix、
  taplo、zizmor；
- `checks`：默认包 + clippy（`-D warnings`，离线、no-default-features）；
- CI 由 buildbot.nix-community.org 托管（README 徽章指向
  project 23），不是 GitHub Actions 主跑；`release.yml` 只在打
  `v*` tag 时用 `gh release create` 建 GitHub Release；
- dependabot：cargo / GitHub Actions 每日、nix 每周，带 cooldown 和
  分组。

## 6. 对我们仓库的启发

- 我们仓库本身不直接需要它，但如果 zhyi-packages 里要打包依赖
  shell 脚本的软件，patsh 或 resholve 是“把脚本命令路径固化进
  store”的现成方案；
- 它的实现值得记住：tree-sitter 做精确 AST 修补、字节区间替换、
  只在目标落在 store 内才改——比 sed/正则改脚本可靠得多；
- `bash -c enable` 枚举 builtin 来避免误 patch，是个很聪明的
  “查官方运行时”做法，和我们规范里“查官方/实际不猜”一致。

## 7. 参考

- [patsh](https://github.com/nix-community/patsh)
- [resholve](https://github.com/abathur/resholve)
