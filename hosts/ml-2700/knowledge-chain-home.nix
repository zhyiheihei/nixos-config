{ lib, pkgs, ... }:
let
  notesReadme = pkgs.writeText "notes-README.md" ''
    # Notes

    私有知识天线：只放不打算公开的内容。

    - `inbox/`：临时捕捉，定期整理
    - `private/`：正式私有笔记
    - `archive/`：归档主题
    - `shared/`：可以升级为公开博客文章的草稿

    约定：Markdown、UTF-8、LF、2 空格缩进（`~/.editorconfig`）。
  '';

  blogReadme = pkgs.writeText "blog-README.md" ''
    # Blog

    公开知识天线：采用作者 `xddxdd/blog` 的 Astro + Markdown/MDX 工作流。

    - `content/`：文章草稿与已发布内容
    - 正式构建和发布流程参考 `docs/learning/author-knowledge-chain.md`

    约定：Markdown/MDX、UTF-8、LF、2 空格缩进（`~/.editorconfig`）。
  '';

  notesGitignore = pkgs.writeText "notes-gitignore" ''
    .DS_Store
    Thumbs.db
    .idea/
    .vscode/
    *.tmp
    .cache/
  '';

  blogGitignore = pkgs.writeText "blog-gitignore" ''
    .astro/
    .DS_Store
    dist/
    node_modules/
    .cache/
  '';
in
{
  home.activation.knowledge-chain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    notes_dir="$HOME/Documents/Notes"
    blog_dir="$HOME/Documents/Blog"

    mkdir -p "$notes_dir/inbox" "$notes_dir/private" "$notes_dir/archive" "$notes_dir/shared"
    mkdir -p "$blog_dir/content"

    if [ ! -f "$notes_dir/README.md" ]; then
      install -m 0644 ${notesReadme} "$notes_dir/README.md"
    fi
    if [ ! -f "$notes_dir/.gitignore" ]; then
      install -m 0644 ${notesGitignore} "$notes_dir/.gitignore"
    fi

    if [ ! -f "$blog_dir/README.md" ]; then
      install -m 0644 ${blogReadme} "$blog_dir/README.md"
    fi
    if [ ! -f "$blog_dir/.gitignore" ]; then
      install -m 0644 ${blogGitignore} "$blog_dir/.gitignore"
    fi
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "knowledge-chain-init" ''
      set -euo pipefail
      notes_dir="$HOME/Documents/Notes"
      blog_dir="$HOME/Documents/Blog"

      if [ ! -d "$notes_dir/.git" ]; then
        git init -b master "$notes_dir"
      fi
      if [ ! -d "$blog_dir/.git" ]; then
        git init -b master "$blog_dir"
      fi

      git -C "$notes_dir" remote remove origin 2>/dev/null || true
      git -C "$notes_dir" remote add origin "ssh://git@git.zhyi.xin:2223/zhyi/notes.git"

      git -C "$blog_dir" remote remove origin 2>/dev/null || true
      git -C "$blog_dir" remote add origin "git@github.com:zhyiheihei/blog.git"

      echo "Private notes: $notes_dir"
      echo "  remote: $(git -C "$notes_dir" remote get-url origin)"
      echo "Public blog: $blog_dir"
      echo "  remote: $(git -C "$blog_dir" remote get-url origin)"
      echo
      echo "Push private notes with: git -C \"$notes_dir\" add -A && git -C \"$notes_dir\" commit -m init && git -C \"$notes_dir\" push -u origin master"
      echo "Push public blog after creating github.com/zhyiheihei/blog: git -C \"$blog_dir\" push -u origin master"
    '')
  ];
}
