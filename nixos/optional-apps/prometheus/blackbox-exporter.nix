{
  pkgs,
  lib,
  LT,
  config,
  ...
}:
let
  blackboxExporterHost = "${config.services.prometheus.exporters.blackbox.listenAddress}:${builtins.toString config.services.prometheus.exporters.blackbox.port}";

  httpMonitorTargets = [
    # Doesn't include main blog as that's monitored by UptimeRobot

    # 3rd party backup hostings for main blog
    "https://github-pages.zhyi.xin"
    "https://netlify.zhyi.xin"
    "https://render.zhyi.xin"
    "https://vercel.zhyi.xin"

    # SSL tests
    "https://letsencrypt-ssl.zhyi.xin"
    "https://zerossl.zhyi.xin"

    # Services under zhyi.xin
    "https://comments.zhyi.xin"
    "https://element.zhyi.xin"
    "https://flapalerted.zhyi.xin"
    "https://git.zhyi.xin"
    "https://lab.zhyi.xin"
    "https://lemmy.zhyi.xin"
    "https://lg.zhyi.xin"
    "https://login.zhyi.xin"
    "https://matrix.zhyi.xin/_matrix/client/versions"
    "https://sip.zhyi.xin"
    "https://tools.zhyi.xin"
    "https://whois.zhyi.xin"

    # Services under zhyi.xin
    # "https://ai.zhyi.xin"
    "https://alert.zhyi.xin"
    "https://asf.zhyi.xin"
    "https://attic.zhyi.xin"
    # "https://books.zhyi.xin"
    "https://bitwarden.zhyi.xin"
    "https://cal.zhyi.xin"
    "https://dashboard.zhyi.xin"
    "https://jellyfin.zhyi.xin"
    "https://lab.zhyi.xin"
    "https://netbox.zhyi.xin"
    "https://prometheus.zhyi.xin"
    "https://rss.zhyi.xin"
    "https://rsshub.zhyi.xin"
    "https://searx.zhyi.xin"
    "https://stats.zhyi.xin"
    # "https://tachidesk.zhyi.xin"
  ];

  monitoredHosts = lib.filterAttrs (
    n: v: v.hasTag LT.tags.server && v.hasTag LT.tags.public-facing
  ) LT.hosts;

  # Cannot monitor self due to hairpin NAT issue
  monitoredHostsExceptSelf = lib.filterAttrs (n: v: n != config.networking.hostName) monitoredHosts;

  httpPublicFacingHosts = lib.mapAttrsToList (n: v: "https://${n}.zhyi.xin") monitoredHosts;

  publicFacingHostsExceptSelf =
    port:
    lib.mapAttrsToList (
      n: v: "${n}.zhyi.xin" + lib.optionalString (port != null) ":${builtins.toString port}"
    ) monitoredHostsExceptSelf;

  relabelConfigs = [
    {
      source_labels = [ "__address__" ];
      target_label = "__param_target";
    }
    {
      source_labels = [ "__param_target" ];
      target_label = "instance";
    }
    {
      target_label = "__address__";
      replacement = blackboxExporterHost;
    }
  ];
in
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    port = LT.port.Prometheus.BlackboxExporter;
    listenAddress = "127.0.0.1";
    configFile = pkgs.writeText "config.yaml" (
      builtins.toJSON {
        modules = {
          https_2xx = {
            prober = "http";
            timeout = "15s";
            http = {
              fail_if_not_ssl = true;
              valid_status_codes = [
                200
                204
                206
                301
                302
                303
                304
                307
                308
              ];
              follow_redirects = false;
            };
          };
          dns = {
            prober = "dns";
            timeout = "15s";
            dns = {
              query_name = "zhyi.dn42";
              query_type = "A";
            };
          };
          gopher = {
            prober = "tcp";
            timeout = "15s";
            tcp.query_response = [
              { send = "/\r\n"; }
              { expect = "gopher\\.lantian\\."; }
            ];
          };
          whois = {
            prober = "tcp";
            timeout = "15s";
            tcp.query_response = [
              { send = "AS4242423712\r\n"; }
              { expect = "LANTIAN-DN42"; }
            ];
          };
        };
      }
    );
  };

  services.prometheus.scrapeConfigs = [
    {
      job_name = "blackbox_exporter";
      static_configs = [ { targets = [ blackboxExporterHost ]; } ];
    }
    {
      job_name = "https_2xx";
      scrape_interval = "1m";
      metrics_path = "/probe";
      params.module = [ "https_2xx" ];
      static_configs = [ { targets = httpMonitorTargets ++ httpPublicFacingHosts; } ];
      relabel_configs = relabelConfigs;
    }
    {
      job_name = "dns";
      scrape_interval = "1m";
      metrics_path = "/probe";
      params.module = [ "dns" ];
      static_configs = [ { targets = publicFacingHostsExceptSelf null; } ];
      relabel_configs = relabelConfigs;
    }
    {
      job_name = "gopher";
      scrape_interval = "1m";
      metrics_path = "/probe";
      params.module = [ "gopher" ];
      static_configs = [ { targets = publicFacingHostsExceptSelf 70; } ];
      relabel_configs = relabelConfigs;
    }
    {
      job_name = "whois";
      scrape_interval = "1m";
      metrics_path = "/probe";
      params.module = [ "whois" ];
      static_configs = [ { targets = publicFacingHostsExceptSelf 43; } ];
      relabel_configs = relabelConfigs;
    }
  ];

  services.prometheus.ruleFiles = [
    (pkgs.writeText "blackbox-exporter.rules" (
      builtins.toJSON {
        groups = [
          {
            name = "blackbox_exporter";
            rules = [
              {
                alert = "https_2xx_web_service_failed";
                expr = ''probe_success{job="https_2xx"} == 0'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "⚠️ {{$labels.alias}}: Web service {{$labels.name}} failed.";
                  description = "{{$labels.alias}} is not returning status code 200 for {{$labels.name}}.";
                };
              }
              {
                alert = "dns_service_failed";
                expr = ''probe_success{job="dns"} == 0'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "⚠️ {{$labels.alias}}: DNS service {{$labels.name}} failed.";
                  description = "{{$labels.alias}} is not returning DNS response for {{$labels.name}}.";
                };
              }
              {
                alert = "gopher_service_failed";
                expr = ''probe_success{job="gopher"} == 0'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "⚠️ {{$labels.alias}}: Gopher service {{$labels.name}} failed.";
                  description = "{{$labels.alias}} is not returning Gopher response for {{$labels.name}}.";
                };
              }
              {
                alert = "whois_service_failed";
                expr = ''probe_success{job="whois"} == 0'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "⚠️ {{$labels.alias}}: WHOIS service {{$labels.name}} failed.";
                  description = "{{$labels.alias}} is not returning WHOIS response for {{$labels.name}}.";
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
