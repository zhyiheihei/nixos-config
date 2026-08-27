# 本机 CUDA 目标裁剪：只编译 sm_75。
#
# eGPU 是 RTX 2080 Ti（Turing，compute capability 7.5）。nixpkgs 默认把
# CUDA 12.9 的全部目标（sm_75～sm_121a）一起编译，nvcc 的 cicc/ptxas 在
# 处理 fattn-mma-f16 系列模板实例时确定性 segfault（signal 11，两次构建
# 在同样的文件上以同样方式崩溃），llama-cpp 因此构建失败、整机部署被卡
# 住。本机只需要 sm_75，裁掉其余目标即完全避开该路径，同时大幅缩短构建
# 时间。由 flake-modules/nixos-configurations.nix 在注入包集时消费。
{
  # 传给 -DCMAKE_CUDA_ARCHITECTURES 的裸数字形式，多目标用分号分隔，
  # 例如 "75;86"。
  capabilitiesString = "75";
}
