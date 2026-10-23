# volcengine（身份服务主机，Dex）

唯一同时运行 Dex 的主机，serve `*.zhyi.xin` 入口域。`hosts/volcengine/*.nix` 不写注释，
理由记录在本文件。

- **secret 属主**：Dex 读取 `dex-oauth-proxy-secret`（公共模块 `oauth2-proxy.nix` 定义，
  默认 `root:root`）；本机是唯一同机运行 Dex 的主机，主机级覆盖该 secret 的属主。
  Vaultwarden 的 SSO 也用这个 secret，以各自服务用户读取。
- **vhost 收敛**：本机承载 `*.zhyi.xin` 入口域；`volcengine.zhyi.xin` 曾经是个没有任何
  服务、也没有对应证书的空壳 vhost，已删除（blackbox 通过显式的 `zhyi.xin` 端点探测
  volcengine）。
- **硬件**：VOLCENGINE 的 QEMU guest，对齐 exam `alice` 的写法关闭 virtio balloon，
  防止内存气球干扰。
- 地域字段即使没有 dn42，server-role 的 BIRD 配置也会读取。
