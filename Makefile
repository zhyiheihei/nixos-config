# 与上游 Makefile 逐字对齐。两个登记偏移：
# ① CN 归属主机部署由发起端（控制机）并行推闭包；
# ② 求值按 EVAL_CHUNK（默认 2）台一批串行（并发求值会打满 32G 内存 OOM）。
# 两者均由 _deploy-tag 实现，标准通道见 docs/agent/deployment.md。

servers: FORCE
	@$(MAKE) _deploy-tag TAG=@server

all: FORCE
	@$(MAKE) _deploy-tag TAG=@default

all-all: FORCE
	@$(MAKE) _deploy-tag TAG=@all

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

PUSH_JOBS ?= 4
EVAL_CHUNK ?= 2

_deploy-tag: FORCE
	@rm -f .gcroots/node-*
	@mkdir -p .gcroots
	@nix eval --json .#colmenaHive.deploymentConfig --apply \
		'x: builtins.mapAttrs (n: v: builtins.concatStringsSep "," v.tags) x' > .gcroots/nodes.txt
	@TAG_NAME=$$(echo $(TAG) | sed 's/^@//'); \
		all_hosts=$$(python3 -c 'import json,sys; d=json.load(open(".gcroots/nodes.txt")); t=sys.argv[1]; print(" ".join(sorted(n for n,v in d.items() if t in v.split(","))))' "$$TAG_NAME"); \
		[ -n "$$all_hosts" ] || { echo "no host matches $(TAG)"; exit 1; }; \
		rm -f .gcroots/build-failed; \
		echo $$all_hosts | xargs -n $(EVAL_CHUNK) | while read PAIR; do \
			nix run .#colmena -- build --on "$$(echo $$PAIR | tr ' ' ',')" \
				|| echo "$$PAIR" >> .gcroots/build-failed; \
		done
	@if [ -e .gcroots/build-failed ]; then \
		echo "=== 构建失败的主机（未部署）: $$(cat .gcroots/build-failed | tr '\n' ' ') ==="; \
	fi
	@push_list=""
	@push_list=""; apply_list=""; \
		for ROOT in .gcroots/node-*; do \
			[ -L "$$ROOT" ] || continue; \
			HOST=$$(echo $$ROOT | sed 's|\.gcroots/node-||'); \
			if grep -q 'geo.cities."CN' hosts/$$HOST/host.nix; then \
				push_list="$$push_list $$HOST"; \
			else \
				apply_list="$$apply_list $$HOST"; \
			fi; \
		done; \
		rm -f .gcroots/deploy-*; \
		status=0; \
		if [ -n "$$apply_list" ]; then \
			nix run .#colmena -- apply --on $$(echo $$apply_list | sed 's/ /,/g') || status=1; \
		fi; \
		if [ -n "$$push_list" ]; then \
			echo $$push_list | tr ' ' '\n' | xargs -P $(PUSH_JOBS) -I{} sh -c '\
				$(MAKE) --no-print-directory _push-host HOST={} > .gcroots/deploy-{}.log 2>&1; \
				echo $$? > .gcroots/deploy-{}.exit'; \
			for HOST in $$push_list; do \
				if [ "$$(cat .gcroots/deploy-$$HOST.exit 2>/dev/null)" -ne 0 ]; then \
					echo "=== $$HOST push 失败 ==="; cat .gcroots/deploy-$$HOST.log; status=1; \
				fi; \
			done; \
		fi; \
		exit $$status

_push-host: FORCE
	@FULL=$$(grep -m1 'hostname' hosts/$(HOST)/host.nix | sed "s/.*\"\(.*\)\".*/\1/"); \
		[ -n "$$FULL" ] || FULL="$(HOST).zhyi.xin"; \
		RESULT=$$(readlink -f .gcroots/node-$(HOST)); \
		nix copy --to "ssh-ng://root@$$FULL:2222" --no-check-sigs $$RESULT \
			&& ssh -p 2222 root@$$FULL "nix-env --profile /nix/var/nix/profiles/system --set $$RESULT && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"

FORCE: ;
