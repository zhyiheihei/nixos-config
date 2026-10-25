_: {
  # 本机为纯 Intel 核显（i915/Mesa），系统残留的 NVIDIA 驱动 ICD 会被 glvnd 枚举，
  # Minecraft（EGL/Wayland）进世界时撞上 NVIDIA ICD 初始化直接 SIGSEGV。
  # 全局锁定 EGL 只用 Mesa vendor。
  environment.sessionVariables.__EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
}
