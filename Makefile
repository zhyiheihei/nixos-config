# 与上游 Makefile 逐字对齐。两个登记偏移：
# ① CN 归属主机（host.nix 的 city 为 geo.cities."CN …"）部署由发起端（控制机）
#    并行推闭包（PUSH_JOBS 默认 4），非 CN 主机保持 colmena apply 原样（目标机自拉缓存）；
# ② push-cache 推 fork 自建缓存（attic 服务别名 zhyi = cache.zhyi.xin）。

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

push-cache: FORCE
	@attic push zhyi $(shell readlink -f .gcroots/*)

PUSH_JOBS ?= 4

_deploy-tag: FORCE
	@rm -f .gcroots/node-*
	@mkdir -p .gcroots
	@nix run .#colmena -- build --on $(TAG)
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
		rm -f .gcroots/.deploy-*; \
		status=0; \
		if [ -n "$$apply_list" ]; then \
			nix run .#colmena -- apply --on $$(echo $$apply_list | sed 's/ /,/g') || status=1; \
		fi; \
		if [ -n "$$push_list" ]; then \
			echo $$push_list | tr ' ' '\n' | xargs -P $(PUSH_JOBS) -I{} sh -c '\
				$(MAKE) --no-print-directory _push-host HOST={} > .gcroots/.deploy-{}.log 2>&1; \
				echo $$? > .gcroots/.deploy-{}.exit'; \
			for HOST in $$push_list; do \
				if [ "$$(cat .gcroots/.deploy-$$HOST.exit 2>/dev/null)" -ne 0 ]; then \
					echo "=== $$HOST push 失败 ==="; cat .gcroots/.deploy-$$HOST.log; status=1; \
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
