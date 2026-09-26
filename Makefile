.DEFAULT_GOAL := help

help: FORCE
	@printf '%s\n' \
		'make                显示本帮助，不执行构建或部署' \
		'make build          构建整个 Colmena Hive，不部署' \
		'make build-default  构建 @default 主机，不部署' \
		'make build-x86      构建 @x86_64-linux 主机，不部署' \
		'make servers        部署并切换 @server 主机' \
		'make all            部署并切换 @default 主机' \
		'make all-all        部署并切换 @all 主机' \
		'make all-boot       以 boot 模式部署 @default 主机' \
		'make all-reboot     部署并重启 @default-non-local 主机' \
		'make all-all-reboot 部署并重启 @non-local 主机' \
		'make local          部署并切换当前主机' \
		'make local-reboot   部署并重启当前主机' \
		'CN 归属地主机（host.nix 的 city 为 geo.cities."CN …"）部署时由控制机' \
		'本地构建后 ssh-ng push 闭包（不依赖目标机拉公共缓存）；非 CN 主机' \
		'保持 colmena apply 原样（目标机自拉缓存）。ssh 后缀强制全部走 push。' \
		'可通过 NIX_OPTS 传递 nix 选项（如 make all NIX_OPTS="--nix-option max-jobs 2"）' \
		'make clean          在 Hive 主机上运行 nixos-cleanup' \
		'make update         更新全部 Flake inputs 和 nvfetcher' \
		'make update-nur     只更新 nur-xddxdd input' \
		'make push-cache     将 .gcroots 中的闭包推送到 Attic'

# no-op target, used as flag: make all ssh
ssh: FORCE

# Optional Nix options passed to colmena, e.g. make all NIX_OPTS="--nix-option max-jobs 2"
NIX_OPTS ?=

servers: FORCE
	@$(MAKE) _deploy-tag TAG=@server PUSH_ALL=$(filter ssh,$(MAKECMDGOALS))

all: FORCE
	@$(MAKE) _deploy-tag TAG=@default PUSH_ALL=$(filter ssh,$(MAKECMDGOALS))

all-all: FORCE
	@$(MAKE) _deploy-tag TAG=@all PUSH_ALL=$(filter ssh,$(MAKECMDGOALS))

all-boot: FORCE
	@nix run .#colmena -- apply boot --on @default $(NIX_OPTS)

all-reboot: FORCE
	@nix run .#colmena -- apply --reboot --on @default-non-local $(NIX_OPTS)

all-all-reboot: FORCE
	@nix run .#colmena -- apply --reboot --on @non-local $(NIX_OPTS)

build: FORCE
	@nix run .#colmena -- build $(NIX_OPTS)

build-default: FORCE
	@nix run .#colmena -- build --on @default $(NIX_OPTS)

build-x86: FORCE
	@nix run .#colmena -- build --on @x86_64-linux $(NIX_OPTS)

local: FORCE
	@nix run .#colmena -- apply --on $(shell cat /etc/hostname) $(NIX_OPTS)

local-reboot: FORCE
	@nix run .#colmena -- apply --reboot --on $(shell cat /etc/hostname) $(NIX_OPTS)

_deploy-tag: FORCE
	@rm -f .gcroots/node-*
	@nix run .#colmena -- build --on $(TAG) $(NIX_OPTS)
	@for ROOT in .gcroots/node-*; do \
		[ -L "$$ROOT" ] || continue; \
		HOST=$$(echo $$ROOT | sed 's|\.gcroots/node-||'); \
		FULL=$$(grep -m1 'hostname' hosts/$$HOST/host.nix | sed "s/.*\"\(.*\)\".*/\1/"); \
		[ -n "$$FULL" ] || FULL="$$HOST.zhyi.xin"; \
		RESULT=$$(readlink -f $$ROOT); \
		echo "=== $$HOST ==="; \
		if [ -n "$(PUSH_ALL)" ] || grep -q 'geo.cities."CN' hosts/$$HOST/host.nix; then \
			nix copy --to "ssh-ng://$$FULL:2222" --no-check-sigs $$RESULT \
				&& ssh -p 2222 $$FULL "nix-env --profile /nix/var/nix/profiles/system --set $$RESULT && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"; \
		else \
			nix run .#colmena -- apply --on $$HOST $(NIX_OPTS); \
		fi; \
		echo "=== $$HOST done ==="; \
	done


clean: FORCE
	@nix run .#colmena -- exec -- nixos-cleanup

update: FORCE
	@nix flake update
	@nix run .#nvfetcher

update-nur: FORCE
	@nix flake update nur-xddxdd

push-cache: FORCE
	@attic push zhyi $(shell readlink -f .gcroots/*)

FORCE: ;
