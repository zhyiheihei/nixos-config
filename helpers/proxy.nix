{ hosts, portStr, ... }:
let
  outboundProxy = "socks5://${hosts.router.interconnect.IPv4}:${portStr.V2Ray.SocksClient}";
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
