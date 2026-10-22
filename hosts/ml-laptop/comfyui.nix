# ComfyUI：本地节点式图像工作流（浏览器 UI，localhost:8188）。
# 用途：作业图片管线——本地只做蒙版/贴回/校验等像素级编排，生成调用
# OpenRouter 云端 API（Seedream），因此无需 CUDA torch，CPU 包即可，
# 也避免 torch+cuda 源码编译的数小时构建。与上游无对应模块，ml-laptop 本机保留项。
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.comfyui ];
}
