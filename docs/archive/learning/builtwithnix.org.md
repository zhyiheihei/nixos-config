# builtwithnix.org 学习笔记

## 1. 是什么

`builtwithnix.org` 是 nix-community 的静态宣传站点源码，zimbatm
维护，51 star，CC-BY-SA-4.0。线上地址
[https://builtwithnix.org](https://builtwithnix.org)，核心功能是
给生态项目提供“Built with Nix”badge：

```markdown
[![Built with Nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
```

`badge.svg` 是 Nix logo + 文字的徽章，很多 nix-community 仓库
（如 autofirma-nix）都在 README 里引用它。

## 2. 站点结构

纯静态页面，没有构建产物生成流程：

- `index.html`：730 行的单页 landing page，用 mobi.css 和少量
  自定义 CSS + SVG 插图；
- `_config.yml`：Jekyll 配置（theme: jekyll-theme-primer，
  CommonMark 渲染），靠 GitHub Pages 部署；
- `CNAME`：绑定 builtwithnix.org 域名；
- `img/`：hero 和功能段落的 SVG 插图；
- `404.html`。

内容结构（旧版 landing page）：

- Hero：**Build software only once**；
- Why Nix?：本机/CI/生产一致、多语言、零到云、丰富包集、
  不重复编译；
- 行业信任背书：tweag.io、Flying Circus、LumiGuide 等；
- Projects built with Nix：精选项目列表（TodoMVC、dapp.tools、
  Rib、Dhall、zoxide、Makes 等）+ badge 嵌入示例（Markdown /
  reStructuredText / AsciiDoc 三种写法）；
- 入门引导。

## 3. 工程与维护

- 仓库没有 GitHub Actions；站点 2024-05 后基本停更；
- 内容许可是 CC-BY-SA-4.0，复用素材需遵循署名相同方式共享；
- 该站点本身“托管在 GitHub Pages、靠 badge.svg 对外传播”的模式
  是组织宣传仓库的标准形态。

## 4. 对我们仓库的启发

- 我们不需要宣传页，不引入；
- 如果以后 zhyi-packages 或文档要挂“Built with Nix”标识，直接
  引用 `https://builtwithnix.org/badge.svg` 即可，不用自绘；
- 它说明 nix-community 里“网站类仓库”也很轻：一个 HTML +
  badge + GitHub Pages，维护成本几乎为零。

## 5. 参考

- [builtwithnix.org](https://github.com/nix-community/builtwithnix.org)
