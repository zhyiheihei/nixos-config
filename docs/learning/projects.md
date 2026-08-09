# projects 学习笔记

## 1. 是什么

`projects` 是 fricklerhandwerk 维护的 **Nix 生态资助项目提案库**：
存放可复用的 fundraising / grant 申请材料（Sovereign Tech Fund、
NLnet 等），供社区成员申请资金时快速起步。14 star，无 license，
纯文档仓库（没有代码）。

## 2. 内容结构

- `README.md`：目的与贡献方式——申请过资金的人把通用问答补进
  faq，把提案加进 proposals；被接受的提案是范例，被拒的也能
  复用，“nothing is lost”；
- `faq.md`：按资助方整理的“Nix 是什么 / 为什么重要 / 谁在用 /
  治理模型 / 谁受益”等标准答案，可整段复用于不同 call；
- `proposals/`：module-migrations、nixpkgs-security-phase2、
  stdenv 文档、stf-general-investment、store、
  `accepted/securing-distribution`；
- `completed/`：已完成项目（2023-12 nixpkgs-security、
  nixpkgs-security）。

## 3. 提案内容特点

提案写得像“可复制的回答模板”：

- 一句话项目描述 + 深挖“为什么关键”；
- 明确依赖（通常是 nixpkgs 内部组件）、目标用户、产出物
  （文档、工具、安全功能）；
- 大量复用生态数据（20 周年、contributor 数量、企业用户、
  binary cache 十年可用等）回答评审问题。

## 4. 对我们仓库的启发

- 我们不需要申请资助，不引入；
- 它是“把社区级问答沉淀成可复用资产”的样板：我们的
  docs/operations、docs/infrastructure 也可以这样积累“标准答案”
  （例如网关链路、主机清单说明）；
- 对 nix-community 生态来说，这类仓库是治理与资金运作的
  背景资料，了解即可。

## 5. 参考

- [projects](https://github.com/nix-community/projects)
