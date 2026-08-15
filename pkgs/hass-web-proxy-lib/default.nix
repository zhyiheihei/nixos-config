{
  lib,
  buildPythonPackage,
  fetchurl,
}:
# Frigate HA 集成的依赖（camera 实体的 Web 代理库）。纯 Python、无依赖。
buildPythonPackage rec {
  pname = "hass-web-proxy-lib";
  version = "0.0.8";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/a3/fd/581b7e7ab1ea6c66ac13ea0c5ed2d74b812c66ace634a96c7bc547b1b3cd/hass_web_proxy_lib-0.0.8.tar.gz";
    sha256 = "sha256-H9C8jwJeR6skvCVn8jeaWqmIL0fmcab+/BQ5SzUIt00=";
  };

  # sdist 用 hatchling（pyproject 构建）。
  pyproject = true;

  meta = {
    description = "Web proxy library used by the Frigate Home Assistant integration";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
