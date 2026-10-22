#!/usr/bin/env bash
# OnePage (ESP32-C61) 固件构建：podman + Ubuntu 24.04 + pioarduino，与作者 README 的官方方式一致。
# 用法：build.sh <crosspoint-onepage 源码目录>
set -euo pipefail
SRC=${1:?源码目录}
podman run --rm --network=host -v "$SRC":/work -v "${HOME}/.cache/pio-c61":/root/.platformio -w /work \
  -e DEBIAN_FRONTEND=noninteractive \
  docker.io/library/ubuntu:24.04 \
  bash -c '
    set -euo pipefail
    if [ ! -x /opt/pio/bin/pio ]; then
      sed -i "s|http://archive.ubuntu.com|http://mirrors.tuna.tsinghua.edu.cn|g; s|http://security.ubuntu.com|http://mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list.d/ubuntu.sources
      apt-get -o Acquire::http::Proxy="DIRECT" update -qq
      apt-get -o Acquire::http::Proxy="DIRECT" install -y -qq python3 python3-venv git ca-certificates >/dev/null
      python3 -m venv /opt/pio
      export http_proxy=http://192.168.0.62:1080 https_proxy=http://192.168.0.62:1080
      /opt/pio/bin/pip install -q -U "https://github.com/pioarduino/platformio-core/archive/refs/tags/v6.1.19.zip"
    fi
    export http_proxy=http://192.168.0.62:1080 https_proxy=http://192.168.0.62:1080
    /opt/pio/bin/pio run -e onepage
  '
