# darwin-build-box 学习笔记

## 1. 是什么

`darwin-build-box` 是 nix-community 给成员用的 Darwin（aarch64 /
x86_64）远程构建机配置仓库，最初由 winterqt 管理，托管费用由
Nix 🖤 macOS Collective 资助。25 star，无明确 license，2023-11
已归档：README 开头写明机器已迁移到
[nix-community/infra](https://github.com/nix-community/infra) 管理
（见 [nix-community.org/community-builder](https://nix-community.org/community-builder)）。

## 2. nix-darwin 配置

`darwin-configuration.nix` 很薄：

- `services.nix-daemon.enable = true`；
- `nix.settings.sandbox = "relaxed"`（macOS 沙箱限制多）；
- `nix.settings.extra-platforms = [ "x86_64-darwin" ]`：arm64
  Mac 靠 Rosetta 也能跑 x86_64 构建；
- `nix.settings.max-jobs = 64`，`nrBuildUsers = max-jobs * 2`；
- 装 git/vim，开 zsh（Catalina 默认 shell）。

## 3. 用户管理

`users.nix`：

- 手工维护用户列表（name/uid/trusted），`createHome = true`，
  shell 固定 zsh，`forceRecreate = true`；
- SSH 公钥放 `keys/<username>`，用
  `environment.etc."ssh/authorized_keys.d/<name>"` 挂进系统；
- `nix.settings.trusted-users` 由列表里 `trusted = true` 的成员
  生成。

申请方式就是 PR：把自己加进 `users.nix` 并放 key 文件。

## 4. 安全边界（README 反复强调）

remote builder 的用户必然是 Nix `trusted-user`，而 trusted user 有
能力影响整个 Nix store（导入任意 NAR、指定 cache），所以：

1. 不要用这台机器构建含私密数据/工具的系统；
2. 不要用它做二进制 bootstrap 工具链（或做 bootstrap 的工具），
   因为要被长期信任；
3. 本地配置示例：`buildMachines` 指到
   `darwin-build-box.winter.cafe`，`maxJobs = 4`，支持
   `aarch64-darwin` / `x86_64-darwin`，SSH key 必须无密码，并校验
   known_hosts 指纹。

## 5. 对我们仓库的启发

- 我们没有 Darwin 构建需求，不引入；
- “用户列表 + keys 目录 + trusted-users 生成”是社区构建机的标准
  权限模型；我们若开放 ml-builder 给协作方，可复用同样结构；
- 构建机迁移进 `infra`（已学）说明组织机器的最终归宿是声明式
  infra 仓库，这类过渡小仓库学会后不用保留。

## 6. 参考

- [darwin-build-box](https://github.com/nix-community/darwin-build-box)
- [nix-community/infra](https://github.com/nix-community/infra)
