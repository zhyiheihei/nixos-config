{
  pkgs,
  prometheusDatasourceUid,
}:
let
  datasource = {
    type = "prometheus";
    uid = prometheusDatasourceUid;
  };

  query =
    {
      expr,
      refId ? "A",
      legendFormat ? "",
      instant ? false,
      format ? "time_series",
    }:
    {
      inherit
        expr
        refId
        legendFormat
        instant
        format
        ;
      datasource = datasource;
      range = !instant;
    };

  thresholds =
    steps:
    {
      mode = "absolute";
      inherit steps;
    };

  stat =
    {
      id,
      title,
      x,
      y,
      w ? 4,
      h ? 4,
      expr,
      unit ? "short",
      decimals ? null,
      description ? "",
      steps ? [
        {
          color = "red";
          value = null;
        }
        {
          color = "green";
          value = 1;
        }
      ],
      colorMode ? "value",
      graphMode ? "area",
    }:
    {
      inherit
        id
        title
        description
        datasource
        ;
      type = "stat";
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      fieldConfig = {
        defaults = {
          inherit unit decimals;
          color.mode = "thresholds";
          thresholds = thresholds steps;
          mappings = [ ];
        };
        overrides = [ ];
      };
      options = {
        inherit colorMode graphMode;
        justifyMode = "auto";
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        textMode = "auto";
        wideLayout = true;
      };
      targets = [
        (query {
          inherit expr;
          instant = true;
        })
      ];
    };

  timeseries =
    {
      id,
      title,
      x,
      y,
      w ? 12,
      h ? 8,
      targets,
      unit ? "short",
      description ? "",
      min ? null,
      max ? null,
      decimals ? null,
      fillOpacity ? 16,
    }:
    {
      inherit
        id
        title
        description
        datasource
        ;
      type = "timeseries";
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      fieldConfig = {
        defaults = {
          inherit
            unit
            min
            max
            decimals
            ;
          color.mode = "palette-classic";
          custom = {
            axisBorderShow = false;
            axisCenteredZero = false;
            axisColorMode = "text";
            axisLabel = "";
            axisPlacement = "auto";
            barAlignment = 0;
            drawStyle = "line";
            fillOpacity = fillOpacity;
            gradientMode = "opacity";
            hideFrom = {
              legend = false;
              tooltip = false;
              viz = false;
            };
            insertNulls = false;
            lineInterpolation = "smooth";
            lineWidth = 2;
            pointSize = 4;
            scaleDistribution.type = "linear";
            showPoints = "never";
            spanNulls = true;
            stacking = {
              group = "A";
              mode = "none";
            };
            thresholdsStyle.mode = "off";
          };
          mappings = [ ];
          thresholds = thresholds [
            {
              color = "green";
              value = null;
            }
          ];
        };
        overrides = [ ];
      };
      options = {
        legend = {
          calcs = [
            "lastNotNull"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "desc";
        };
      };
      targets = map query targets;
    };

  table =
    {
      id,
      title,
      x,
      y,
      w ? 24,
      h ? 9,
      expr,
      description ? "",
      exclude ? { },
      rename ? { },
      sortBy ? [ ],
    }:
    {
      inherit
        id
        title
        description
        datasource
        ;
      type = "table";
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      fieldConfig = {
        defaults = {
          custom = {
            align = "auto";
            cellOptions.type = "auto";
            footer.reducers = [ ];
            inspect = false;
          };
          mappings = [ ];
          thresholds = thresholds [
            {
              color = "red";
              value = null;
            }
            {
              color = "green";
              value = 1;
            }
          ];
        };
        overrides = [ ];
      };
      options = {
        cellHeight = "sm";
        showHeader = true;
        sortBy = sortBy;
      };
      targets = [
        (query {
          inherit expr;
          instant = true;
          format = "table";
        })
      ];
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = exclude;
            indexByName = { };
            renameByName = rename;
          };
        }
      ];
    };

  row =
    {
      id,
      title,
      y,
    }:
    {
      inherit id title;
      type = "row";
      collapsed = false;
      gridPos = {
        x = 0;
        inherit y;
        w = 24;
        h = 1;
      };
      panels = [ ];
    };

  dashboard =
    {
      uid,
      title,
      panels,
      tags,
      refresh ? "30s",
      from ? "now-6h",
    }:
    {
      annotations.list = [
        {
          builtIn = 1;
          datasource = {
            type = "grafana";
            uid = "-- Grafana --";
          };
          enable = true;
          hide = true;
          iconColor = "rgba(0, 211, 255, 1)";
          name = "Annotations & Alerts";
          type = "dashboard";
        }
      ];
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = [ ];
      liveNow = false;
      inherit
        panels
        refresh
        tags
        title
        uid
        ;
      schemaVersion = 41;
      style = "dark";
      templating.list = [ ];
      time = {
        inherit from;
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      version = 1;
      weekStart = "monday";
    };

  infrastructureOverview = dashboard {
    uid = "zhyi-overview";
    title = "基础设施总览";
    tags = [
      "zhyi"
      "infrastructure"
    ];
    panels = [
      (stat {
        id = 1;
        title = "在线主机";
        x = 0;
        y = 0;
        expr = ''sum(up{job="node"})'';
        description = "Node Exporter 当前可达的主机数量";
      })
      (stat {
        id = 2;
        title = "监控主机总数";
        x = 4;
        y = 0;
        expr = ''count(up{job="node"})'';
        colorMode = "background";
      })
      (stat {
        id = 3;
        title = "正常采集目标";
        x = 8;
        y = 0;
        expr = "sum(up)";
      })
      (stat {
        id = 4;
        title = "失败采集目标";
        x = 12;
        y = 0;
        expr = "count(up) - sum(up)";
        steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "red";
            value = 1;
          }
        ];
        colorMode = "background";
      })
      (stat {
        id = 5;
        title = "公网服务可用";
        x = 16;
        y = 0;
        expr = ''sum(probe_success{job="https_2xx"})'';
      })
      (stat {
        id = 6;
        title = "最短证书剩余";
        x = 20;
        y = 0;
        expr = ''(min(probe_ssl_earliest_cert_expiry{job="https_2xx"}) - time()) / 86400'';
        unit = "d";
        decimals = 1;
        steps = [
          {
            color = "red";
            value = null;
          }
          {
            color = "orange";
            value = 14;
          }
          {
            color = "green";
            value = 30;
          }
        ];
      })
      (row {
        id = 10;
        title = "主机资源";
        y = 4;
      })
      (timeseries {
        id = 11;
        title = "CPU 使用率";
        x = 0;
        y = 5;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''100 - avg by(instance) (rate(node_cpu_seconds_total{job="node",mode="idle"}[5m])) * 100'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (timeseries {
        id = 12;
        title = "内存使用率";
        x = 12;
        y = 5;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''(1 - node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes{job="node"}) * 100'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (timeseries {
        id = 13;
        title = "系统负载";
        x = 0;
        y = 13;
        targets = [
          {
            expr = ''node_load1{job="node"}'';
            legendFormat = "{{instance}} 1m";
          }
          {
            expr = ''node_load5{job="node"}'';
            legendFormat = "{{instance}} 5m";
          }
        ];
      })
      (timeseries {
        id = 14;
        title = "/nix 文件系统使用率";
        x = 12;
        y = 13;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''(1 - node_filesystem_avail_bytes{job="node",mountpoint="/nix",fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{job="node",mountpoint="/nix",fstype!~"tmpfs|overlay"}) * 100'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (row {
        id = 20;
        title = "网络与服务";
        y = 21;
      })
      (timeseries {
        id = 21;
        title = "主机网络吞吐";
        x = 0;
        y = 22;
        unit = "bps";
        targets = [
          {
            expr = ''sum by(instance) (rate(node_network_receive_bytes_total{job="node",device!~"lo|veth.*|ns-.*|podman.*|dummy.*"}[5m])) * 8'';
            legendFormat = "{{instance}} 接收";
          }
          {
            expr = ''sum by(instance) (rate(node_network_transmit_bytes_total{job="node",device!~"lo|veth.*|ns-.*|podman.*|dummy.*"}[5m])) * 8'';
            legendFormat = "{{instance}} 发送";
          }
        ];
      })
      (timeseries {
        id = 22;
        title = "失败 systemd 单元";
        x = 12;
        y = 22;
        unit = "short";
        min = 0;
        targets = [
          {
            expr = ''sum by(instance) (node_systemd_unit_state{job="node",state="failed"})'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (table {
        id = 23;
        title = "采集目标状态";
        x = 0;
        y = 30;
        h = 12;
        expr = "up";
        exclude = {
          Time = true;
          "__name__" = true;
          Value = false;
        };
        rename = {
          instance = "实例";
          job = "采集任务";
          Value = "状态";
        };
        sortBy = [
          {
            desc = false;
            displayName = "状态";
          }
        ];
      })
    ];
  };

  routerOverview = dashboard {
    uid = "zhyi-router";
    title = "家庭路由器";
    tags = [
      "zhyi"
      "router"
      "network"
    ];
    panels = [
      (stat {
        id = 1;
        title = "路由器在线";
        x = 0;
        y = 0;
        expr = ''up{job="node",instance="router"}'';
        colorMode = "background";
      })
      (stat {
        id = 2;
        title = "PPPoE WAN";
        x = 4;
        y = 0;
        expr = ''node_network_up{job="node",instance="router",device="ppp0"}'';
        colorMode = "background";
      })
      (stat {
        id = 3;
        title = "运行时间";
        x = 8;
        y = 0;
        expr = ''time() - node_boot_time_seconds{job="node",instance="router"}'';
        unit = "s";
      })
      (stat {
        id = 4;
        title = "CPU 使用率";
        x = 12;
        y = 0;
        expr = ''100 - avg(rate(node_cpu_seconds_total{job="node",instance="router",mode="idle"}[5m])) * 100'';
        unit = "percent";
        decimals = 1;
        steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "orange";
            value = 70;
          }
          {
            color = "red";
            value = 90;
          }
        ];
      })
      (stat {
        id = 5;
        title = "内存使用率";
        x = 16;
        y = 0;
        expr = ''(1 - node_memory_MemAvailable_bytes{job="node",instance="router"} / node_memory_MemTotal_bytes{job="node",instance="router"}) * 100'';
        unit = "percent";
        decimals = 1;
        steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "orange";
            value = 75;
          }
          {
            color = "red";
            value = 90;
          }
        ];
      })
      (stat {
        id = 6;
        title = "活跃 DHCP 租约";
        x = 20;
        y = 0;
        expr = ''router_dhcp_active_leases{instance="router"}'';
      })
      (row {
        id = 10;
        title = "接口流量";
        y = 4;
      })
      (timeseries {
        id = 11;
        title = "WAN 实时吞吐";
        x = 0;
        y = 5;
        unit = "bps";
        targets = [
          {
            expr = ''rate(node_network_receive_bytes_total{job="node",instance="router",device="ppp0"}[2m]) * 8'';
            legendFormat = "下载";
          }
          {
            expr = ''rate(node_network_transmit_bytes_total{job="node",instance="router",device="ppp0"}[2m]) * 8'';
            legendFormat = "上传";
          }
        ];
      })
      (timeseries {
        id = 12;
        title = "LAN 实时吞吐";
        x = 12;
        y = 5;
        unit = "bps";
        targets = [
          {
            expr = ''rate(node_network_receive_bytes_total{job="node",instance="router",device="br-lan"}[2m]) * 8'';
            legendFormat = "接收";
          }
          {
            expr = ''rate(node_network_transmit_bytes_total{job="node",instance="router",device="br-lan"}[2m]) * 8'';
            legendFormat = "发送";
          }
        ];
      })
      (timeseries {
        id = 13;
        title = "接口丢包与错误";
        x = 0;
        y = 13;
        unit = "pps";
        targets = [
          {
            expr = ''sum by(device) (rate(node_network_receive_drop_total{job="node",instance="router",device=~"ppp0|br-lan"}[5m]) + rate(node_network_transmit_drop_total{job="node",instance="router",device=~"ppp0|br-lan"}[5m]))'';
            legendFormat = "{{device}} 丢包";
          }
          {
            expr = ''sum by(device) (rate(node_network_receive_errs_total{job="node",instance="router",device=~"ppp0|br-lan"}[5m]) + rate(node_network_transmit_errs_total{job="node",instance="router",device=~"ppp0|br-lan"}[5m]))'';
            legendFormat = "{{device}} 错误";
          }
        ];
      })
      (timeseries {
        id = 14;
        title = "Conntrack 使用情况";
        x = 12;
        y = 13;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''router_conntrack_entries{instance="router"} / router_conntrack_limit{instance="router"} * 100'';
            legendFormat = "连接跟踪表";
          }
        ];
      })
      (row {
        id = 20;
        title = "DNS 与核心服务";
        y = 21;
      })
      (timeseries {
        id = 21;
        title = "DNS 请求速率";
        x = 0;
        y = 22;
        unit = "qps";
        targets = [
          {
            expr = ''sum(rate(coredns_dns_requests_total{instance="router"}[5m]))'';
            legendFormat = "请求";
          }
          {
            expr = ''sum(rate(coredns_dns_responses_total{instance="router"}[5m]))'';
            legendFormat = "响应";
          }
        ];
      })
      (timeseries {
        id = 22;
        title = "核心服务状态";
        x = 12;
        y = 22;
        min = 0;
        max = 1;
        targets = [
          {
            expr = ''node_systemd_unit_state{job="node",instance="router",state="active",name=~"pppd-wan.service|kea-dhcp4-server.service|coredns.service|dae.service|nftables.service|zerotierone.service"}'';
            legendFormat = "{{name}}";
          }
        ];
      })
      (row {
        id = 30;
        title = "局域网设备";
        y = 30;
      })
      (table {
        id = 31;
        title = "当前网络邻居";
        x = 0;
        y = 31;
        w = 14;
        h = 12;
        expr = ''router_neighbor_info{instance="router"}'';
        exclude = {
          Time = true;
          "__name__" = true;
          instance = true;
          job = true;
          Value = true;
        };
        rename = {
          address = "IP 地址";
          mac = "MAC 地址";
          hostname = "主机名";
          device = "接口";
          state = "邻居状态";
        };
        sortBy = [
          {
            desc = false;
            displayName = "IP 地址";
          }
        ];
      })
      (table {
        id = 32;
        title = "活跃 DHCP 租约";
        x = 14;
        y = 31;
        w = 10;
        h = 12;
        expr = ''router_dhcp_lease_info{instance="router"}'';
        exclude = {
          Time = true;
          "__name__" = true;
          instance = true;
          job = true;
          Value = true;
        };
        rename = {
          address = "IP 地址";
          mac = "MAC 地址";
          hostname = "主机名";
        };
        sortBy = [
          {
            desc = false;
            displayName = "IP 地址";
          }
        ];
      })
    ];
  };

  serviceHealth = dashboard {
    uid = "zhyi-service-health";
    title = "服务与网络健康";
    tags = [
      "zhyi"
      "services"
      "network"
    ];
    refresh = "1m";
    from = "now-24h";
    panels = [
      (stat {
        id = 1;
        title = "公网检查总数";
        x = 0;
        y = 0;
        expr = ''count(probe_success{job="https_2xx"})'';
      })
      (stat {
        id = 2;
        title = "公网检查成功";
        x = 4;
        y = 0;
        expr = ''sum(probe_success{job="https_2xx"})'';
      })
      (stat {
        id = 3;
        title = "公网检查失败";
        x = 8;
        y = 0;
        expr = ''count(probe_success{job="https_2xx"}) - sum(probe_success{job="https_2xx"})'';
        colorMode = "background";
        steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "red";
            value = 1;
          }
        ];
      })
      (stat {
        id = 4;
        title = "采集目标失败";
        x = 12;
        y = 0;
        expr = "count(up) - sum(up)";
        colorMode = "background";
        steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "red";
            value = 1;
          }
        ];
      })
      (stat {
        id = 5;
        title = "WireGuard 正常握手";
        x = 16;
        y = 0;
        expr = "sum(wireguard_latest_handshake_delay_seconds < 300)";
      })
      (stat {
        id = 6;
        title = "证书最短剩余";
        x = 20;
        y = 0;
        expr = ''(min(probe_ssl_earliest_cert_expiry{job="https_2xx"}) - time()) / 86400'';
        unit = "d";
        decimals = 1;
        steps = [
          {
            color = "red";
            value = null;
          }
          {
            color = "orange";
            value = 14;
          }
          {
            color = "green";
            value = 30;
          }
        ];
      })
      (row {
        id = 10;
        title = "外部服务";
        y = 4;
      })
      (timeseries {
        id = 11;
        title = "公网服务响应时间";
        x = 0;
        y = 5;
        unit = "s";
        targets = [
          {
            expr = ''probe_duration_seconds{job="https_2xx"}'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (timeseries {
        id = 12;
        title = "TLS 证书剩余天数";
        x = 12;
        y = 5;
        unit = "d";
        targets = [
          {
            expr = ''(probe_ssl_earliest_cert_expiry{job="https_2xx"} - time()) / 86400'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (table {
        id = 13;
        title = "公网服务当前状态";
        x = 0;
        y = 13;
        h = 13;
        expr = ''probe_success{job="https_2xx"}'';
        exclude = {
          Time = true;
          "__name__" = true;
          job = true;
        };
        rename = {
          instance = "地址";
          Value = "状态";
        };
        sortBy = [
          {
            desc = false;
            displayName = "状态";
          }
        ];
      })
      (row {
        id = 20;
        title = "组网与 DNS";
        y = 26;
      })
      (timeseries {
        id = 21;
        title = "WireGuard 握手延迟";
        x = 0;
        y = 27;
        unit = "s";
        targets = [
          {
            expr = "wireguard_latest_handshake_delay_seconds";
            legendFormat = "{{instance}} / {{public_key}}";
          }
        ];
      })
      (timeseries {
        id = 22;
        title = "WireGuard 流量";
        x = 12;
        y = 27;
        unit = "Bps";
        targets = [
          {
            expr = "sum by(instance) (rate(wireguard_received_bytes_total[5m]))";
            legendFormat = "{{instance}} 接收";
          }
          {
            expr = "sum by(instance) (rate(wireguard_sent_bytes_total[5m]))";
            legendFormat = "{{instance}} 发送";
          }
        ];
      })
      (timeseries {
        id = 23;
        title = "各节点 DNS 请求速率";
        x = 0;
        y = 35;
        unit = "qps";
        targets = [
          {
            expr = "sum by(instance) (rate(coredns_dns_requests_total[5m]))";
            legendFormat = "{{instance}}";
          }
        ];
      })
      (timeseries {
        id = 24;
        title = "BIRD 协议在线状态";
        x = 12;
        y = 35;
        min = 0;
        max = 1;
        targets = [
          {
            expr = "bird_protocol_up";
            legendFormat = "{{instance}} / {{name}}";
          }
        ];
      })
    ];
  };
in
pkgs.linkFarm "grafana-dashboards" [
  {
    name = "infrastructure-overview.json";
    path = pkgs.writeText "infrastructure-overview.json" (builtins.toJSON infrastructureOverview);
  }
  {
    name = "router-overview.json";
    path = pkgs.writeText "router-overview.json" (builtins.toJSON routerOverview);
  }
  {
    name = "service-health.json";
    path = pkgs.writeText "service-health.json" (builtins.toJSON serviceHealth);
  }
]
