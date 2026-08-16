# nix-data-science 学习笔记

## 1. 是什么

`nix-data`（仓库名 nix-data-science）是给数据科学家准备的“batteries
included”Nix 包集合，重点覆盖 Python 和 R，构建针对 Intel MKL 与
NVIDIA CUDA/cuDNN。MIT 协议，84 star，项目已较旧（约 2021 年停更）。

## 2. 结构

- `nixpkgs.nix`：pin 固定 nixpkgs SHA，允许 unfree
  （cudatoolkit/cudnn）；
- `overlays.nix`：
  - 顶层：openmpi CUDA、ffmpeg-full（nvenc/nonfree）；
  - Python：BLAS/LAPACK 用 MKL，pytorch/tensorflow 开 CUDA、
    opencv 开 CUDA+FFmpeg；
- `jobsets/`：`hello.nix`、`python.nix`、`r.nix`，供 Hydra 构建；
- `spec.nix` / `spec.json`：Hydra jobset 声明（legacy、固定
  checkinterval 等）。

## 3. CI

- GitHub Actions `deploy.yml` 矩阵构建 hello/python/r jobset，
  推送到 Cachix（tbenst）。

## 4. 对我们仓库的启发

- 我们不跑数据科学负载，不需要引入；
- 它的价值是历史参考：用 overlay 把 BLAS/MKL/CUDA/FFmpeg 组合
  起来并 pin nixpkgs，这类“为特定领域定制 overlay”的模式在
  其他领域仓库（如 nixpkgs-xr）里延续了下来。

## 5. 参考

- [nix-data-science](https://github.com/nix-community/nix-data-science)
