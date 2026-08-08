{
  LT,
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDir = "/var/lib/docker-proxy";
  registryHosts = [
    "hub.zhyi.cc"
    "ghcr.zhyi.cc"
    "gcr.zhyi.cc"
    "k8s.zhyi.cc"
    "k8s-gcr.zhyi.cc"
    "quay.zhyi.cc"
    "mcr.zhyi.cc"
    "elastic.zhyi.cc"
    "nvcr.zhyi.cc"
  ];
  goProxyConfig = pkgs.writeText "docker-proxy-config.yaml" ''
    server:
      listen: ":5000"
      admin_listen: ":5001"
      read_timeout: 60
      write_timeout: 0
      idle_timeout: 120
    default: dockerhub
    log_level: normal
    access_control:
      mode: off
    registries:
      - name: dockerhub
        hosts:
          - "hub.zhyi.cc"
          - "registry-1.docker.io"
        upstream: "https://registry-1.docker.io"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: ghcr
        hosts:
          - "ghcr.zhyi.cc"
        upstream: "https://ghcr.io"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: gcr
        hosts:
          - "gcr.zhyi.cc"
        upstream: "https://gcr.io"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: k8sgcr
        hosts:
          - "k8s-gcr.zhyi.cc"
        upstream: "https://k8s.gcr.io"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: k8s
        hosts:
          - "k8s.zhyi.cc"
        upstream: "https://registry.k8s.io"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: quay
        hosts:
          - "quay.zhyi.cc"
        upstream: "https://quay.io"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: mcr
        hosts:
          - "mcr.zhyi.cc"
        upstream: "https://mcr.microsoft.com"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: elastic
        hosts:
          - "elastic.zhyi.cc"
        upstream: "https://docker.elastic.co"
        auth:
          type: token
        token_cache_ttl: 3600
      - name: nvcr
        hosts:
          - "nvcr.zhyi.cc"
        upstream: "https://nvcr.io"
        auth:
          type: token
        token_cache_ttl: 3600
  '';
in
{
  virtualisation.oci-containers.containers = {
    docker-proxy-go-proxy = {
      image = "docker.io/dqzboy/registry:latest";
      labels."io.containers.autoupdate" = "registry";
      networks = [ "docker-proxy" ];
      hostname = "go-proxy";
      environmentFiles = [ "${stateDir}/env" ];
      ports = [ "127.0.0.1:${LT.portStr.DockerProxy.Registry}:5000" ];
      volumes = [ "${stateDir}/go-proxy:/app/config.d" ];
    };
    docker-proxy-hubcmd-ui = {
      image = "docker.io/dqzboy/hubcmd-ui:latest";
      labels."io.containers.autoupdate" = "registry";
      networks = [ "docker-proxy" ];
      hostname = "hubcmd-ui";
      dependsOn = [ "docker-proxy-go-proxy" ];
      environment = {
        GO_PROXY_ADMIN_URL = "http://go-proxy:5001";
        HOST_NAME = config.networking.hostName;
        SECURE_COOKIE = "true";
        PORT = "3000";
      };
      environmentFiles = [ "${stateDir}/env" ];
      ports = [ "127.0.0.1:${LT.portStr.DockerProxy.UI}:3000" ];
      volumes = [
        "${stateDir}/hubcmd-ui:/app/data"
        "/var/run/docker.sock:/var/run/docker.sock"
      ];
    };
  };

  systemd.tmpfiles.settings.docker-proxy = {
    "${stateDir}"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    "${stateDir}/go-proxy"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    "${stateDir}/hubcmd-ui"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };

  systemd.services.docker-proxy-bootstrap = {
    description = "Bootstrap Docker-Proxy network, credentials and config";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [
      "podman-docker-proxy-go-proxy.service"
      "podman-docker-proxy-hubcmd-ui.service"
    ];
    requiredBy = [
      "podman-docker-proxy-go-proxy.service"
      "podman-docker-proxy-hubcmd-ui.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      ${pkgs.podman}/bin/podman network exists docker-proxy || \
        ${pkgs.podman}/bin/podman network create --opt dns_enabled=true docker-proxy
      if [ ! -f ${stateDir}/env ]; then
        umask 077
        {
          echo "GO_PROXY_ADMIN_TOKEN=$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -dc 'a-zA-Z0-9' | ${pkgs.coreutils}/bin/head -c 32)"
          echo "SESSION_SECRET=$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -dc 'a-zA-Z0-9' | ${pkgs.coreutils}/bin/head -c 32)"
        } > ${stateDir}/env
      fi
      if [ ! -f ${stateDir}/go-proxy/config.yaml ]; then
        ${pkgs.coreutils}/bin/install -Dm 0644 ${goProxyConfig} ${stateDir}/go-proxy/config.yaml
      fi
    '';
  };

  lantian.nginxVhosts = lib.genAttrs registryHosts (host: {
    locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.DockerProxy.Registry}";
    locations."/".proxyNoTimeout = true;
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
    accessibleBy = "public";
  }) // {
    "docker-proxy.zhyi.cc" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.DockerProxy.UI}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        enableOAuth = true;
      };
      sslCertificate = "lets-encrypt-zhyi.cc";
      noIndex.enable = true;
      accessibleBy = "public";
    };
  };
}
