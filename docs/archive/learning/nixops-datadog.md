# nixops-datadog 学习笔记

## 1. 是什么

`nixops-datadog` 是 NixOps 的 Datadog 资源插件（Amine Chikhaoui，
LGPL-3.0，4 star，Python，2020-04 后停更）：用 Nix 声明式管理
Datadog monitor / timeboard / screenboard，并给部署加 downtime /
event 集成。

## 2. 功能

- `datadog_utils.py`：
  - `initializeDatadog`：API/APP key 从选项或
    `DATADOG_API_KEY` / `DATADOG_APP_KEY` 环境变量读取；
  - downtime：按 deployment uuid 创建/更新/删除，标记
    `NIXOPS GENERATED`，用于部署维护窗口；
  - `create_event`：部署时往 Datadog 发事件（可开关）。
- `resources/`：`datadog_monitor` / `datadog_timeboard` /
  `datadog_screenboard` 三个 ResourceState，用 datadog API 增删改；
- `nix/`：resources 声明（`datadogMonitors` 等），examples 三个
  资源示例。

## 3. 打包与插件机制

- `plugin.py` 用 NixOps 旧 hookimpl API（nixexprs/load），entry
  point `datadog`；
- `setup.py` 带 `@version@` 占位符，`release.nix` 是老式 python2
  构建（与 nixops-vbox 等早期插件同款）。

## 4. 对我们仓库的启发

- 我们用 Prometheus/自建监控，不引入；
- 它和 nixops-gce/hcloud 等属于 NixOps 资源插件谱系；
  “downtime + deployment event”把部署和维护窗口自动联动是
  不错的设计，我们以后若给 ml-builder 加监控维护流程可参考。

## 5. 参考

- [nixops-datadog](https://github.com/nix-community/nixops-datadog)
