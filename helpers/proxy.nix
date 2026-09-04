# 集群统一出站代理常量：router V2Ray SOCKS5 及配套环境变量。
# 所有需要代理的服务（systemd unit environment、environment.variables、
# nix-daemon 等）一律引用这里，禁止在 host/模块内内联拼 socks5://。
{ hosts, portStr, ... }:
let
  outboundProxy = "socks5://${hosts.router.interconnect.IPv4}:${portStr.V2Ray.SocksClient}";
  # 基础 bypass：回环 + home LAN（192.168.0.0/16）+ LTNET（198.18.0.0/15，
  # 实际使用 198.18.0.0/16）+ 集群域名。个别服务要豁免更多域名（如
  # m-team、docker.m.daocloud.io）时以 "${LT.proxyBypass},<追加>" 覆盖。
  proxyBypass = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin";
  proxyEnvironment = {
    HTTP_PROXY = outboundProxy;
    HTTPS_PROXY = outboundProxy;
    NO_PROXY = proxyBypass;
    http_proxy = outboundProxy;
    https_proxy = outboundProxy;
    no_proxy = proxyBypass;
  };
in
{
  inherit outboundProxy proxyBypass proxyEnvironment;
}
