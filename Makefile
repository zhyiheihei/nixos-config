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
		'make deploy-ssh HOST=xxx  单台 ssh push 部署（构建在本地，push closure 到目标机）' \
		'在 all/all-all/servers 后加 ssh 后缀可用 ssh push 模式部署，' \
		'避免目标机用旧配置自己拉缓存（如 make all ssh）' \
		'make clean          在 Hive 主机上运行 nixos-cleanup' \
		'make update         更新全部 Flake inputs 和 nvfetcher' \
		'make update-nur     只更新 nur-xddxdd input' \
		'make push-cache     将 .gcroots 中的闭包推送到 Attic'

# no-op target, used as flag: make all ssh
ssh: FORCE

servers: FORCE
	@if [ "$(filter ssh,$(MAKECMDGOALS))" ]; then $(MAKE) _deploy-tag TAG=@server; \
	else nix run .#colmena -- apply --on @server; fi

all: FORCE
	@if [ "$(filter ssh,$(MAKECMDGOALS))" ]; then $(MAKE) _deploy-tag TAG=@default; \
	else nix run .#colmena -- apply --on @default; fi

all-all: FORCE
	@if [ "$(filter ssh,$(MAKECMDGOALS))" ]; then $(MAKE) _deploy-tag TAG=@all; \
	else nix run .#colmena -- apply --on @all; fi

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

# ssh push 部署：colmena 并行 build --keep-result，然后逐台 push closure + activate
_deploy-tag: FORCE
	@nix run .#colmena -- build --on $(TAG) --keep-result --eval-node-limit 5 --parallel 0
	@for ROOT in .gcroots/node-*; do \
		[ -L "$$ROOT" ] || continue; \
		HOST=$$(echo $$ROOT | sed 's|\.gcroots/node-||'); \
		FULL=$$(grep -m1 'hostname' hosts/$$HOST/host.nix | sed "s/.*\"\(.*\)\".*/\1/"); \
		RESULT=$$(readlink -f $$ROOT); \
		echo "=== $$HOST ==="; \
		nix copy --to "ssh-ng://$$FULL:2222" $$RESULT || { echo "copy failed for $$HOST, skipping"; continue; }; \
		ssh -p 2222 $$FULL "nix-env --profile /nix/var/nix/profiles/system --set $$RESULT && /nix/var/nix/profiles/system/bin/switch-to-configuration switch" || echo "activate failed for $$HOST"; \
		echo "=== $$HOST done ==="; \
	done

deploy-ssh: FORCE
	@if [ -z "$(HOST)" ]; then echo "Usage: make deploy-ssh HOST=ml-laptop"; exit 1; fi
	@for HOST in $(HOST); do \
		echo "=== $$HOST ==="; \
		RESULT=$$(nix build .#nixosConfigurations.$$HOST.config.system.build.toplevel --no-link --print-out-paths 2>&1); \
		if [ $$? -ne 0 ]; then echo "Build failed for $$HOST: $$RESULT"; continue; fi; \
		FULL=$$(grep -m1 'hostname' hosts/$$HOST/host.nix | sed "s/.*\"\(.*\)\".*/\1/"); \
		echo "Built: $$RESULT"; \
		nix copy --to "ssh-ng://$$FULL:2222" $$RESULT; \
		ssh -p 2222 $$FULL "nix-env --profile /nix/var/nix/profiles/system --set $$RESULT && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"; \
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
	@attic push lantian $(shell readlink -f .gcroots/*)

FORCE: ;
