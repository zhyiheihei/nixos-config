# fetchTree-spec 学习笔记

## 1. 是什么

`fetchTree-spec` 是 roberth / flokli / lf- 发起的
`builtins.fetchTree` 与 flake lock 条目的**规范 + 一致性测试套件**
仓库。16 star，无 license，2024-10 后基本停更，目前**只有一个
README**（Work in progress）。

## 2. 动机

- `fetchTree` 是 Nix 表达式里访问外部仓库（git 等）的机制；语言
  追求可复现，因此它在不同 Nix 实现（Nix / Lix / 其他）之间、
  不同版本之间的行为必须一致；
- 行为一旦漂移，就产生不同的 derivation，进而导致二进制缓存
  失效；
- 与 fixed-output derivation 对比：FOD 需要执行表达式提供的代码
  且靠输出 hash 验证，`fetchTree` 不执行代码，因此更值得精确
  钉死语义。

## 3. 目标形态

仓库打算提供：

- 一份 `fetchTree` 行为规范；
- 一套 conformance suite（测试用例文件），可直接放进各 Nix
  实现的测试套件跑。

目前只有 README，还没有规范正文和用例。

## 4. 对我们仓库的启发

- 我们日常大量依赖 flake.lock + fetchTree，知道“lock 条目语义必须
  跨实现一致”很重要（比如 flake-compat 的手写 fetchTree 模拟也
  是在复制这些语义）；
- 规范/一致性套件比“写死测试”更适合跨实现项目；若 zhyi-packages
  未来有自研解析器，可参照这种组织方式。

## 5. 参考

- [fetchTree-spec](https://github.com/nix-community/fetchTree-spec)
