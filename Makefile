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
		'make deploy-ssh HOST=xxx   在本机构建后通过 ssh 推送给目标主机' \
		'make deploy-ssh-all       遍历所有主机执行 deploy-ssh' \
		'make deploy-ssh-default   遍历 @default 主机执行 deploy-ssh' \
		'make clean          在 Hive 主机上运行 nixos-cleanup' \
		'make update         更新全部 Flake inputs 和 nvfetcher' \
		'make update-nur     只更新 nur-xddxdd input' \
		'make push-cache     将 .gcroots 中的闭包推送到 Attic'

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

deploy-ssh: FORCE
	@if [ -z "$(HOST)" ]; then echo "Usage: make deploy-ssh HOST=ml-laptop"; exit 1; fi
	@for HOST in $(HOST); do \
		echo "=== $$HOST ==="; \
		RESULT=$$(nix build .#nixosConfigurations.$$HOST.config.system.build.toplevel --no-link --print-out-paths 2>&1); \
		if [ $$? -ne 0 ]; then echo "Build failed for $$HOST: $$RESULT"; continue; fi; \
		echo "Built: $$RESULT"; \
		echo "Copying closure to $$HOST via ssh..."; \
		nix-store --export $$(nix-store -qR $$RESULT) | ssh -p 2222 $$HOST 'nix-store --import'; \
		echo "Activating on $$HOST..."; \
		ssh -p 2222 $$HOST "nix-env --profile /nix/var/nix/profiles/system --set $$RESULT && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"; \
		echo "=== $$HOST done ==="; \
	done

deploy-ssh-all: FORCE
	@for HOST in $$(ls hosts/); do \
		$(MAKE) deploy-ssh HOST=$$HOST || true; \
	done

deploy-ssh-default: FORCE
	@for HOST in $$(grep -L manualDeploy hosts/*/host.nix | sed 's|hosts/||;s|/host.nix||'); do \
		$(MAKE) deploy-ssh HOST=$$HOST || true; \
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
