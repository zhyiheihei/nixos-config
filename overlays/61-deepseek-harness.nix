# pkgs.deepseek-harness：预置 nixpkgs PR #553134（0.1.0-rc.6）官方包定义。
# nixpkgs 合并进 unstable 后删本文件与 pkgs/deepseek-harness/（见该目录 README）。
_: final: prev: {
  deepseek-harness = final.callPackage ../pkgs/deepseek-harness { };
}