# 学习笔记（项目相关）

本目录只保留**与本项目（NixOS 复刻）相关**的学习笔记：项目实际使用的工具
（flake inputs / home 模块命中）与复刻学习专属文档。其余 nix-community 生态
工具笔记已归档至 [`../../archive/learning`](../../archive/learning)，不作为
当前学习依据（追溯历史生态笔记时去那边查）。

## 复刻学习总纲

- [Nix 复刻学习总纲](nix-replication-guide.md) —— 以复刻 xddxdd 两套仓库为路径的总纲
- [Star 排序学习清单](star-ranked-curriculum.md) —— 按 star 排序的学习路线图（状态随进度更新）
- [作者知识链：私有 + 公开两天线](author-knowledge-chain.md)
- [知识链完整链路与上游对齐审计](knowledge-chain-upstream-alignment.md)
- [知识链 Syncthing 三节点实施规划](knowledge-chain-rollout-plan.md)

## 项目仓库相关

- [zhyi-packages 维护指南](zhyi-packages-guide.md)
- [NUR 生态链（zhyi-packages 的生态位置）](nur-chain.md)
- [NUR 用户包注册表](NUR.md)
- [nur-packages-template（zhyi-packages 的模板参照）](nur-packages-template.md)

## 项目实际使用的工具

### Flake 基础设施

- [colmena 多主机部署](colmena.md)
- [home-manager 用户环境声明式管理](home-manager.md)
- [flake-parts 模块化 flake 框架](flake-parts.md)
- [flake-compat 兼容非 flake 项目](flake-compat.md)
- [srvos 服务器优化](srvos.md)

### 磁盘与系统

- [impermanence 易失根持久化](impermanence.md)
- [preservation 非易失状态管理](preservation.md)

### 开发工具

- [nixd Nix language server](nixd.md)
- [nix-init 从 URL 生成包](nix-init.md)
- [nix-direnv direnv 的 use_flake](nix-direnv.md)
- [nix-index nix 文件定位](nix-index.md)
- [nix-index-database nix-index 预生成数据库](nix-index-database.md)

### 桌面与主题

- [plasma-manager KDE Plasma 的 Home Manager 模块](plasma-manager.md)
- [stylix 统一主题框架](stylix.md)

> 归档区 [`../../archive/learning`](../../archive/learning) 收录 205 篇纯
> nix-community 生态工具笔记（dream2nix、nixops、nixpkgs-* 系列等），
> 与本项目无直接使用关系。
