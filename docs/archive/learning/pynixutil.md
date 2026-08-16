# pynixutil 学习笔记

## 1. 是什么

`pynixutil` 是 adisbladis 写的 Python 工具库：处理来自 Nix 的数据。
14 star，MIT，Python 3.8+，源自 Trustix 项目（Tweag + NLnet +
NGI Zero PET 资助），2022-10 后基本停更。

两个核心功能：

```python
import pynixutil

# Nix base32 字母表编码/解码（0-9abc... 与标准 base32 互转）
pynixutil.b32encode(pynixutil.b32decode("v5sv61sszx301i0x6xysaqzla09nksnd"))

# 解析 .drv，结构对齐 `nix show-derivation`
drv = pynixutil.drvparse(open("hello-2.10.drv").read())
```

## 2. 实现

- `base32.py`：用 `base64.b32encode/decode` + 两张 translate 表，
  在标准 base32 字母表（A-Z2-7）和 Nix 字母表
  （0-9abcdfghijklmnpqrsvwxyz）之间映射；
- `drv.py`：返回 dataclass
  `Derivation` / `DerivationOutput`（outputs、input_drvs、
  input_srcs、system、builder、args、env；`platform` 是
  Nix 2.4 前 `system` 的别名）；解析直接用 Python `ast` 处理
  drv 文本的嵌套结构；
- 带 `py.typed`，类型提示完整。

## 3. 测试与工程

- `tests/fixtures/` 放真实 .drv（firefox、jq、hello），pytest
  覆盖 base32 和 drv 解析；
- `shell.nix`：poetry2nix 环境 + `nix_2_3`（测试用固定 Nix
  版本）；CI 跑 `black --check` + `pytest`；
- poetry 打包，无其它依赖。

## 4. 对我们仓库的启发

- 我们目前用 Rust/Go 工具链，不需要引入；
- 如果 zhyi-packages 将来写 Python 侧 Nix 工具（如生成器、
  lockfile 处理），b32 和 drv 解析是常用基础件，可直接复用；
- 它来自 Trustix（和 lila 同类），说明“小而独立的库 + 真实
  fixture 测试”适合作为大型安全项目的一部分抽出来维护。

## 5. 参考

- [pynixutil](https://github.com/nix-community/pynixutil)
