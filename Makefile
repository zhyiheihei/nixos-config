CURRENT_HOSTS := ml-builder,ml-home-vm,pve-5700u,colocrossing,twvm,jpvm
.DEFAULT_GOAL := help

help: FORCE
	@printf '%s\n' \
		'make                显示本帮助，不执行构建或部署' \
		'make current-eval   求值当前在线主机，不构建、不部署' \
		'make current-build  构建当前在线主机，不部署' \
		'make current        部署并切换当前在线主机' \
		'make servers        部署并切换 @server 主机' \
		'make all            部署并切换 @default 主机' \
		'make all-all        部署并切换 @all 主机' \
		'make all-boot       以 boot 模式部署 @default 主机' \
		'make all-reboot     部署并重启 @default-non-local 主机' \
		'make all-all-reboot 部署并重启 @non-local 主机' \
		'make build          构建整个 Colmena Hive，不部署' \
		'make build-default  构建 @default 主机，不部署' \
		'make build-x86      构建 @x86_64-linux 主机，不部署' \
		'make local          部署并切换当前主机' \
		'make local-reboot   部署并重启当前主机' \
		'make clean          在 Hive 主机上运行 nixos-cleanup' \
		'make update         更新全部 Flake inputs 和 nvfetcher' \
		'make update-nur     只更新 nur-xddxdd input' \
		'make push-cache     将 .gcroots 中的闭包推送到 Attic'

current-eval: FORCE
	@set -e; \
	for host in $$(printf '%s' '$(CURRENT_HOSTS)' | tr ',' ' '); do \
		printf 'Evaluating %s... ' "$$host"; \
		nix eval --raw ".#nixosConfigurations.$$host.config.system.build.toplevel.drvPath" >/dev/null; \
		printf 'done\n'; \
	done

current-build: FORCE
	@nix run .#colmena -- build --on $(CURRENT_HOSTS)

# Backward-compatible aliases for the old target names.
four-eval: current-eval

four: current-build

current: FORCE
	@nix run .#colmena -- apply --on $(CURRENT_HOSTS)

servers: FORCE
	@nix run .#colmena -- apply --on @server

all: FORCE
	@nix run .#colmena -- apply --on @default

all-all: FORCE
	@nix run .#colmena -- apply --on @all

all-boot: FORCE
	@nix run .#colmena -- apply boot --on @default

all-reboot: FORCE
	@nix run .#colmena -- apply --reboot --on @default-non-local

all-all-reboot: FORCE
	@nix run .#colmena -- apply --reboot --on @non-local

build: FORCE
	@nix run .#colmena -- build

build-default: FORCE
	@nix run .#colmena -- build --on @default

build-x86: FORCE
	@nix run .#colmena -- build --on @x86_64-linux

local: FORCE
	@nix run .#colmena -- apply --on $(shell cat /etc/hostname)

local-reboot: FORCE
	@nix run .#colmena -- apply --reboot --on $(shell cat /etc/hostname)

clean: FORCE
	@nix run .#colmena -- exec -- nixos-cleanup

update: FORCE
	@nix flake update
	@nix run .#nvfetcher

update-nur: FORCE
	@nix flake update nur-xddxdd

push-cache: FORCE
	@attic push lantian $(shell readlink -f .gcroots/*)

FORCE: ;
