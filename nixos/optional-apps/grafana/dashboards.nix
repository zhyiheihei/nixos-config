{
  lib,
  pkgs,
  prometheusDatasourceUid,
}:
let
  datasource = {
    type = "prometheus";
    uid = prometheusDatasourceUid;
  };

  # Grafana rejects multiple queries with the same refId inside one panel;
  # assign each target a unique letter.
  refIds = [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ];

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
      targets = lib.imap1 (i: t: query (t // { refId = builtins.elemAt refIds (i - 1); })) targets;
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
      preload = false;
      inherit
        panels
        refresh
        tags
        title
        uid
        ;
      schemaVersion = 42;
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
        title = "文件系统使用率";
        x = 12;
        y = 13;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''(1 - node_filesystem_avail_bytes{job="node",fstype!~"tmpfs|overlay|devtmpfs|squashfs"} / node_filesystem_size_bytes{job="node",fstype!~"tmpfs|overlay|devtmpfs|squashfs"}) * 100'';
            legendFormat = "{{instance}} {{mountpoint}}";
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
      (row {
        id = 30;
        title = "数据库与反向代理";
        y = 30;
      })
      (timeseries {
        id = 31;
        title = "MySQL 连接数";
        x = 0;
        y = 31;
        targets = [
          {
            expr = ''mysql_global_status_threads_connected{job="mysql"}'';
            legendFormat = "{{instance}} 连接";
          }
          {
            expr = ''mysql_global_variables_max_connections{job="mysql"}'';
            legendFormat = "{{instance}} 上限";
          }
        ];
      })
      (timeseries {
        id = 32;
        title = "Nginx 请求速率";
        x = 12;
        y = 31;
        unit = "qps";
        targets = [
          {
            expr = ''sum by(instance) (rate(nginx_vts_server_requests_total{job="nginx"}[5m]))'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (timeseries {
        id = 33;
        title = "Nginx 流量吞吐";
        x = 0;
        y = 39;
        unit = "bps";
        targets = [
          {
            expr = ''sum by(instance) (rate(nginx_vts_server_bytes_total{job="nginx",direction="in"}[5m])) * 8'';
            legendFormat = "{{instance}} 接收";
          }
          {
            expr = ''sum by(instance) (rate(nginx_vts_server_bytes_total{job="nginx",direction="out"}[5m])) * 8'';
            legendFormat = "{{instance}} 发送";
          }
        ];
      })
      (timeseries {
        id = 34;
        title = "MySQL 慢查询速率";
        x = 12;
        y = 39;
        unit = "qps";
        targets = [
          {
            expr = ''rate(mysql_global_status_slow_queries{job="mysql"}[5m])'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (row {
        id = 50;
        title = "DNS 与路由";
        y = 47;
      })
      (timeseries {
        id = 51;
        title = "CoreDNS 请求速率";
        x = 0;
        y = 48;
        unit = "qps";
        targets = [
          {
            expr = ''sum by(instance,job) (rate(coredns_dns_requests_total{job=~"coredns|coredns-authoritative"}[5m]))'';
            legendFormat = "{{instance}} ({{job}})";
          }
        ];
      })
      (timeseries {
        id = 52;
        title = "BIRD 协议在线状态";
        x = 12;
        y = 48;
        min = 0;
        max = 1;
        targets = [
          {
            expr = ''bird_protocol_up{job="bird"}'';
            legendFormat = "{{instance}} / {{name}}";
          }
        ];
      })
      (timeseries {
        id = 53;
        title = "Prometheus 时序数量";
        x = 0;
        y = 56;
        targets = [
          {
            expr = ''prometheus_tsdb_head_series{job="prometheus"}'';
            legendFormat = "活跃时序";
          }
        ];
      })
      (timeseries {
        id = 54;
        title = "Prometheus 查询速率";
        x = 12;
        y = 56;
        unit = "qps";
        targets = [
          {
            expr = ''rate(prometheus_engine_query_duration_seconds_count{job="prometheus"}[5m])'';
            legendFormat = "{{slice}}";
          }
        ];
      })
      (table {
        id = 40;
        title = "采集目标状态";
        x = 0;
        y = 64;
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
        expr = ''router_wan_address_info{instance="router"}'';
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
            expr = ''node_systemd_unit_state{job="node",instance="router",state="active",name=~"pppd-wan.service|kea-dhcp4-server.service|coredns.service|nftables.service|zerotierone.service|systemd-networkd.service|ntpd-rs.service|prometheus-node-exporter.service"}'';
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
          family = "地址族";
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
      (row {
        id = 40;
        title = "WAN 信息";
        y = 43;
      })
      (table {
        id = 41;
        title = "当前 WAN 地址";
        x = 0;
        y = 44;
        w = 12;
        h = 4;
        expr = ''router_wan_address_info{instance="router"}'';
        exclude = {
          Time = true;
          "__name__" = true;
          instance = true;
          job = true;
          Value = true;
        };
        rename = {
          address = "WAN IP 地址";
        };
        sortBy = [ ];
      })
      (timeseries {
        id = 42;
        title = "邻居状态统计";
        x = 12;
        y = 44;
        targets = [
          {
            expr = ''router_neighbors{instance="router"}'';
            legendFormat = "{{state}}";
          }
        ];
      })
      (row {
        id = 50;
        title = "硬件与系统";
        y = 53;
      })
      (timeseries {
        id = 51;
        title = "温度";
        x = 0;
        y = 54;
        unit = "celsius";
        targets = [
          {
            expr = ''node_hwmon_temp_celsius{instance="router"}'';
            legendFormat = "{{chip}}";
          }
        ];
      })
      (timeseries {
        id = 52;
        title = "系统负载";
        x = 12;
        y = 54;
        targets = [
          {
            expr = ''node_load1{instance="router"}'';
            legendFormat = "1 分钟";
          }
          {
            expr = ''node_load5{instance="router"}'';
            legendFormat = "5 分钟";
          }
          {
            expr = ''node_load15{instance="router"}'';
            legendFormat = "15 分钟";
          }
        ];
      })
      (timeseries {
        id = 53;
        title = "内存明细";
        x = 0;
        y = 62;
        unit = "bytes";
        targets = [
          {
            expr = ''node_memory_MemTotal_bytes{instance="router"} - node_memory_MemAvailable_bytes{instance="router"}'';
            legendFormat = "已用";
          }
          {
            expr = ''node_memory_MemAvailable_bytes{instance="router"}'';
            legendFormat = "可用";
          }
          {
            expr = ''node_memory_Cached_bytes{instance="router"}'';
            legendFormat = "缓存";
          }
          {
            expr = ''node_memory_Buffers_bytes{instance="router"}'';
            legendFormat = "缓冲";
          }
        ];
      })
      (timeseries {
        id = 54;
        title = "磁盘读写速率";
        x = 12;
        y = 62;
        unit = "Bps";
        targets = [
          {
            expr = ''rate(node_disk_read_bytes_total{instance="router"}[5m])'';
            legendFormat = "{{device}} 读";
          }
          {
            expr = ''rate(node_disk_written_bytes_total{instance="router"}[5m])'';
            legendFormat = "{{device}} 写";
          }
        ];
      })
      (row {
        id = 60;
        title = "存储";
        y = 70;
      })
      (timeseries {
        id = 61;
        title = "文件系统使用率";
        x = 0;
        y = 71;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''(1 - node_filesystem_avail_bytes{instance="router",fstype!~"tmpfs|overlay|proc|sysfs|devtmpfs|devpts|ramfs|cgroup"} / node_filesystem_size_bytes{instance="router",fstype!~"tmpfs|overlay|proc|sysfs|devtmpfs|devpts|ramfs|cgroup"}) * 100'';
            legendFormat = "{{mountpoint}}";
          }
        ];
      })
      (timeseries {
        id = 62;
        title = "磁盘 IO 占用";
        x = 12;
        y = 71;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''rate(node_disk_io_time_seconds_total{instance="router"}[5m]) * 100'';
            legendFormat = "{{device}}";
          }
        ];
      })
      (row {
        id = 70;
        title = "DNS 性能";
        y = 79;
      })
      (timeseries {
        id = 71;
        title = "缓存命中率";
        x = 0;
        y = 80;
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''100 * sum(rate(coredns_cache_hits_total{instance="router"}[5m])) / (sum(rate(coredns_cache_hits_total{instance="router"}[5m])) + sum(rate(coredns_cache_misses_total{instance="router"}[5m])))'';
            legendFormat = "命中率";
          }
        ];
      })
      (timeseries {
        id = 72;
        title = "上游 DNS 延迟";
        x = 12;
        y = 80;
        unit = "s";
        targets = [
          {
            # proxy 插件指标已废弃；核心请求延迟直方图（Prometheus 3 存为
            # native histogram，标签为 server/zone）
            expr = ''coredns_dns_request_duration_seconds{instance="router"}'';
            legendFormat = "{{server}} {{zone}}";
          }
        ];
      })
      (timeseries {
        id = 73;
        title = "DNS 异常";
        x = 0;
        y = 88;
        targets = [
          {
            expr = ''rate(coredns_panics_total{instance="router"}[5m])'';
            legendFormat = "panic";
          }
          {
            expr = ''rate(coredns_reload_failed_total{instance="router"}[5m])'';
            legendFormat = "重载失败";
          }
          {
            expr = ''rate(coredns_forward_healthcheck_broken_total{instance="router"}[5m])'';
            legendFormat = "上游健康检查断开";
          }
          {
            expr = ''rate(coredns_forward_max_concurrent_rejects_total{instance="router"}[5m])'';
            legendFormat = "并发超限拒绝";
          }
        ];
      })
      (timeseries {
        id = 74;
        title = "DNS 请求按类型";
        x = 12;
        y = 88;
        unit = "qps";
        targets = [
          {
            expr = ''sum by (type) (rate(coredns_dns_requests_total{instance="router"}[5m]))'';
            legendFormat = "{{type}}";
          }
        ];
      })
      (row {
        id = 80;
        title = "接口总览";
        y = 96;
      })
      (timeseries {
        id = 81;
        title = "各接口实时吞吐";
        x = 0;
        y = 97;
        w = 24;
        unit = "bps";
        targets = [
          {
            expr = ''sum by (device) (rate(node_network_receive_bytes_total{instance="router"}[2m])) * 8'';
            legendFormat = "{{device}} 下行";
          }
          {
            expr = ''sum by (device) (rate(node_network_transmit_bytes_total{instance="router"}[2m])) * 8'';
            legendFormat = "{{device}} 上行";
          }
        ];
      })
      (table {
        id = 82;
        title = "链路速率";
        x = 0;
        y = 105;
        w = 12;
        h = 8;
        expr = ''node_network_speed_bytes{instance="router"}'';
        exclude = {
          Time = true;
          "__name__" = true;
          instance = true;
          job = true;
          Value = true;
        };
        rename = {
          device = "接口";
          speed = "链路速率";
        };
        sortBy = [
          {
            desc = false;
            displayName = "接口";
          }
        ];
      })
      (timeseries {
        id = 83;
        title = "链路抖动 (载波变化)";
        x = 12;
        y = 105;
        targets = [
          {
            expr = ''rate(node_network_carrier_changes_total{instance="router"}[5m])'';
            legendFormat = "{{device}}";
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
      (row {
        id = 30;
        title = "证书与媒体服务";
        y = 43;
      })
      (timeseries {
        id = 31;
        title = "ACME 证书剩余天数";
        x = 0;
        y = 44;
        unit = "d";
        targets = [
          {
            expr = ''ssl_certificate_expiry_seconds{job="acme-cert"} / 86400'';
            legendFormat = "{{hostname}} {{dns_names}}";
          }
        ];
      })
      (timeseries {
        id = 32;
        title = "媒体服务状态";
        x = 12;
        y = 44;
        min = 0;
        max = 1;
        targets = [
          {
            expr = ''up{job=~"sonarr|radarr|prowlarr|bazarr"}'';
            legendFormat = "{{job}} / {{instance}}";
          }
        ];
      })
      (timeseries {
        id = 33;
        title = "Sonarr/Radarr 媒体状态";
        x = 0;
        y = 52;
        targets = [
          {
            expr = ''sonarr_episode_missing_total{job="sonarr"}'';
            legendFormat = "sonarr 缺失";
          }
          {
            expr = ''sonarr_episode_downloaded_total{job="sonarr"}'';
            legendFormat = "sonarr 已下载";
          }
          {
            expr = ''radarr_movie_missing_total{job="radarr"}'';
            legendFormat = "radarr 缺失";
          }
          {
            expr = ''radarr_movie_downloaded_total{job="radarr"}'';
            legendFormat = "radarr 已下载";
          }
        ];
      })
      (timeseries {
        id = 34;
        title = "Prowlarr 索引器状态";
        x = 12;
        y = 52;
        targets = [
          {
            expr = ''prowlarr_indexer_total{job="prowlarr"}'';
            legendFormat = "{{instance}} 索引器";
          }
          {
            expr = ''prowlarr_indexer_enabled_total{job="prowlarr"}'';
            legendFormat = "{{instance}} 已启用";
          }
        ];
      })
      (row {
        id = 40;
        title = "协议探测";
        y = 60;
      })
      (timeseries {
        id = 41;
        title = "DNS 探测状态";
        x = 0;
        y = 61;
        min = 0;
        max = 1;
        targets = [
          {
            expr = ''probe_success{job="dns"}'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (timeseries {
        id = 42;
        title = "Gopher/WHOIS 探测状态";
        x = 12;
        y = 61;
        min = 0;
        max = 1;
        targets = [
          {
            expr = ''probe_success{job="gopher"}'';
            legendFormat = "gopher {{instance}}";
          }
          {
            expr = ''probe_success{job="whois"}'';
            legendFormat = "whois {{instance}}";
          }
        ];
      })
      (row {
        id = 50;
        title = "基础设施服务";
        y = 69;
      })
      (timeseries {
        id = 51;
        title = "PostgreSQL 连接数";
        x = 0;
        y = 70;
        targets = [
          {
            expr = ''sum by(instance) (pg_stat_activity_count{job="postgres"})'';
            legendFormat = "{{instance}}";
          }
        ];
      })
      (timeseries {
        id = 52;
        title = "磁盘 SMART 健康";
        x = 12;
        y = 70;
        min = 0;
        max = 1;
        targets = [
          {
            expr = ''smartctl_device_smart_status{job="smartctl"}'';
            legendFormat = "{{instance}} {{device}}";
          }
        ];
      })
      (timeseries {
        id = 53;
        title = "磁盘温度";
        x = 0;
        y = 78;
        unit = "celsius";
        targets = [
          {
            expr = ''smartctl_device_temperature{job="smartctl"}'';
            legendFormat = "{{instance}} {{device}}";
          }
        ];
      })
      (row {
        id = 60;
        title = "外部服务";
        y = 86;
      })
      (timeseries {
        id = 61;
        title = "外部服务可用性";
        x = 0;
        y = 87;
        min = 0;
        max = 1;
        targets = [
          {
            expr = ''up{job=~"sakura-share|flapalerted"}'';
            legendFormat = "{{job}}";
          }
        ];
      })
      (row {
        id = 70;
        title = "权威 DNS 详情";
        y = 95;
      })
      (timeseries {
        id = 71;
        title = "Knot 区域数量";
        x = 0;
        y = 96;
        targets = [
          {
            expr = ''sum by(instance) (knot_stats_zone_count{job="knot"})'';
            legendFormat = "{{instance}}";
          }
        ];
      })
    ];
  };
  infrastructureOverviewJson =
    pkgs.writeText "infrastructure-overview.json" (builtins.toJSON infrastructureOverview);
  routerOverviewJson = pkgs.writeText "router-overview.json" (builtins.toJSON routerOverview);
  serviceHealthJson = pkgs.writeText "service-health.json" (builtins.toJSON serviceHealth);
in
pkgs.runCommand "grafana-dashboards" { } ''
  mkdir -p "$out"
  install -m 0444 ${infrastructureOverviewJson} "$out/infrastructure-overview.json"
  install -m 0444 ${routerOverviewJson} "$out/router-overview.json"
  install -m 0444 ${serviceHealthJson} "$out/service-health.json"
''
