{ ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ./ddns-gcore.nix
    ./dhcp.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./prometheus.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/client-components/multicast-dns.nix
    ../../nixos/optional-apps/dae.nix
    ../../nixos/optional-apps/miniupnpd.nix
    ../../nixos/optional-apps/nmea-static-gps-server.nix
    ../../nixos/optional-apps/ncps-client.nix
  ];

  services.miniupnpd = {
    externalInterface = "ppp0";
    internalIPs = [ "br-lan" ];
  };

  lantian.dae = {
    lanInterfaces = [ "br-lan" ];
    proxyDomains = [
      "chatgpt.com"
      "challenges.cloudflare.com"
      "cursor.sh"
      "dns.google"
      "ghcr.io"
      "github.com"
      "githubassets.com"
      "githubcopilot.com"
      "githubusercontent.com"
      "oaistatic.com"
      "oaiusercontent.com"
      "openai.com"
      "vscode-cdn.net"
      "kernel.org"
      "gitlab.com"
      "gitlab.io"
      "gitlab-static.net"
      "google.com"
      "golang.org"
      "ghcr.io"
      "proxy.golang.org"
      "storage.googleapis.com"
      "sum.golang.org"
      "elastic.co"
    ];
    intlAction = "must_direct";
  };

}
