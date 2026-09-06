# NUR resin 1.2.0 的 vendorHash 与 proxy.golang.org 实际内容不符
# （spec sha256-iLZR…，实测 sha256-j6Jn…），导致任何机器都构建失败，
# 挡住 opi5p 整个闭包。vendorHash 不是包的外层 callPackage 参数，故经
# buildGoModule 参数注入；NUR 侧以 finalAttrs lambda 调用，两种形态都
# 兼容。上游 NUR 修复 vendorHash 后删除本文件。
_: final: prev: {
  nur-xddxdd = prev.nur-xddxdd // {
    resin = prev.nur-xddxdd.resin.override {
      buildGoModule =
        args:
        let
          inject =
            attrs:
            attrs
            // {
              vendorHash = "sha256-j6Jn7iIVJaWtKXHZAojAz9EiDBzaIqYeCVRdajnhBGc=";
            };
        in
        final.buildGoModule (if builtins.isFunction args then a: inject (args a) else inject args);
    };
  };
}
