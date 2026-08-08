# comma 学习笔记

## 1. 是什么

`comma` 让你“不安装也能运行” nixpkgs 里的软件：在命令前加一个逗号即可。

```bash
, cowsay neato
```

原理很简单：

- 用 `nix-index` 数据库反查“哪个包提供了这个可执行文件”；
- 再用 `nix shell -c` 临时进入该包环境并执行命令；
- 缓存选择结果和 store path，让后续调用接近毫秒级。

## 2. 依赖

- `nix-index`：按文件名查包的数据库；
- `nix-index-database`：提供预生成数据库，避免自己跑全量索引。

## 3. 缓存级别

- `0`：完全不缓存；
- `1`：只缓存“命令到 derivation”的选择结果；
- `2`（默认）：同时缓存已经求值的 store path。

缓存级别越高越快，但可能跑不到最新版本；需要最新版本时设
`COMMA_CACHING=1`。

## 4. 对我们仓库的启发

`comma` 依赖的 `nix-index` 已经在前面学过了。实际使用场景是开发机快速试
命令；服务器部署场景我们仍用 colmena/Attic，不需要它。

## 5. 参考

- [comma](https://github.com/nix-community/comma)
- [nix-index-database](https://github.com/nix-community/nix-index-database)
