# carnix 学习笔记

## 1. 是什么

`carnix`（nix-community fork）是 tazjin 维护的 **carnix 源码 git
镜像**：一个“从 Cargo.lock 生成 Rust crates 的 Nix 表达式”的早期
工具，作者 P-E-Meunier。10 star，无 license，Rust，2019-02 已归档。

README 明说：这不是开发仓库，开发在 Pijul Nest，这里只镜像
crates.io 发布版本并附带 changelog。

## 2. 历史意义

- carnix 是 Rust + Nix 自动打包的**第一代**方案，后来被
  cargo2nix / crate2nix / naersk 等取代（naersk 我们已学）；
- 早期没有 SQLite 缓存、支持 `cargo generate-nixfile` 子命令、
  workspace 的 src/member 拆分、build script 环境变量等；
- 它和 mavenix、emacs2nix 等一样属于“lockfile → Nix 生成器”
  谱系，只是 Rust 侧早已迭代换代。

## 3. 对我们仓库的启发

- 我们不需要旧 carnix，Rust 打包用 nixpkgs `buildRustPackage` /
  cargo2nix；
- 这个仓库提醒我们：镜像型 org 仓库常是“供历史引用”的存在，
  学的时候重点记谱系和替代品，不用深入研究旧代码。

## 4. 参考

- [carnix](https://github.com/nix-community/carnix)
