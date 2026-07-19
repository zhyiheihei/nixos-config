{ portStr, ... }:
{
  server = builtins.toJSON { "m.server" = "matrix.zhyi.xin:${portStr.Matrix.Public}"; };
  client = builtins.toJSON {
    "m.server"."base_url" = "https://matrix.zhyi.xin";
    "m.homeserver"."base_url" = "https://matrix.zhyi.xin";
    "m.homeserver"."server_name" = "zhyi.xin";
    "m.identity_server"."base_url" = "https://vector.im";
    "org.matrix.msc3575.proxy"."url" = "https://matrix.zhyi.xin";
  };
}
