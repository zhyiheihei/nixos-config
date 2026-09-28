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
		'make push-cache     将 .gcroots 中的闭包推送到 Attic' \
		'并发说明：求值按 EVAL_CHUNK（默认 2）台一批串行进行，避免并发求值打满内存；' \
		'分发阶段 CN 归属/ssh 后缀主机按 PUSH_JOBS（默认 4）并发 push，' \
		'非 CN 主机合并为一次 colmena apply（colmena 内部并发），两路同时执行。'

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

PUSH_JOBS ?= 4
EVAL_CHUNK ?= 2

_deploy-tag: FORCE
	@rm -f .gcroots/node-*
	@mkdir -p .gcroots
	@nix eval .#colmenaHive.deploymentConfig --apply \
		'x: builtins.mapAttrs (n: v: builtins.concatStringsSep "," v.tags) x' > .gcroots/nodes.txt
	@TAG_NAME=$$(echo $(TAG) | sed 's/^@//'); \
		all_hosts=$$(python3 -c 'import json,sys; d=json.load(open(".gcroots/nodes.txt")); t=sys.argv[1]; print(" ".join(sorted(n for n,v in d.items() if t in v.split(","))))' "$$TAG_NAME"); \
		[ -n "$$all_hosts" ] || { echo "no host matches $(TAG)"; exit 1; }; \
		echo "=== 求值分批（每批 $(EVAL_CHUNK) 台串行）: $$all_hosts ==="; \
		echo $$all_hosts | xargs -n $(EVAL_CHUNK) | while read PAIR; do \
			nix run .#colmena -- build --on "$$(echo $$PAIR | tr ' ' ',')" $(NIX_OPTS) || exit 1; \
		done; \
		[ $$? -eq 0 ] || exit 1
	@push_list=""; apply_list=""; \
		for ROOT in .gcroots/node-*; do \
			[ -L "$$ROOT" ] || continue; \
			HOST=$$(echo $$ROOT | sed 's|\.gcroots/node-||'); \
			if [ -n "$(PUSH_ALL)" ] || grep -q 'geo.cities."CN' hosts/$$HOST/host.nix; then \
				push_list="$$push_list $$HOST"; \
			else \
				apply_list="$$apply_list $$HOST"; \
			fi; \
		done; \
		rm -f .gcroots/deploy-*; \
		if [ -n "$$apply_list" ]; then \
			echo "=== colmena apply:$${apply_list}（并发） ==="; \
			( nix run .#colmena -- apply --on $$(echo $$apply_list | sed 's/ /,/g') $(NIX_OPTS) >.gcroots/deploy-colmena.log 2>&1; echo $$? >.gcroots/deploy-colmena.exit ) & \
		fi; \
		if [ -n "$$push_list" ]; then \
			echo "=== push 并发（PUSH_JOBS=$(PUSH_JOBS)）:$$push_list ==="; \
			echo $$push_list | tr ' ' '\n' | xargs -P $(PUSH_JOBS) -I{} sh -c '\
				$(MAKE) --no-print-directory _push-host HOST={} > .gcroots/deploy-{}.log 2>&1; \
				echo $$? > .gcroots/deploy-{}.exit'; \
		fi; \
		wait; \
		status=0; \
		if [ -e .gcroots/deploy-colmena.exit ]; then \
			if [ "$$(cat .gcroots/deploy-colmena.exit)" -ne 0 ]; then \
				echo "=== colmena apply 失败 ==="; cat .gcroots/deploy-colmena.log; status=1; \
			else echo "=== colmena apply done ==="; fi; \
		fi; \
		for HOST in $$push_list; do \
			if [ "$$(cat .gcroots/deploy-$$HOST.exit 2>/dev/null)" -ne 0 ]; then \
				echo "=== $$HOST 失败 ==="; cat .gcroots/deploy-$$HOST.log; status=1; \
			else echo "=== $$HOST done ==="; fi; \
		done; \
		exit $$status

_push-host: FORCE
	@FULL=$$(grep -m1 'hostname' hosts/$(HOST)/host.nix | sed "s/.*\"\(.*\)\".*/\1/"); \
		[ -n "$$FULL" ] || FULL="$(HOST).zhyi.xin"; \
		RESULT=$$(readlink -f .gcroots/node-$(HOST)); \
		nix copy --to "ssh-ng://$$FULL:2222" --no-check-sigs $$RESULT \
			&& ssh -p 2222 $$FULL "nix-env --profile /nix/var/nix/profiles/system --set $$RESULT && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"


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
