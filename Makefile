# 与上游 Makefile 逐字对齐。一个登记偏移：
# ① 部署目标（servers/all/all-all）按 host.nix 的 geo.cities."CN 分两组顺序部署，
#    各组都是原版 colmena apply（终端内原生 spinner、每台实时时间）：CN 组加
#    --no-substitute，闭包全量由部署端推送（CN 机自拉缓存网络不稳）；非 CN 组
#    保持原版行为，目标机自拉缓存补齐。分组不经过 colmena，直接读
#    hosts/<名>/host.nix 的 tags 与 city。

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

DEPLOY_CN_PARALLEL ?= 4

_deploy-tag: FORCE
	@tag=$$(printf '%s' '$(TAG)' | sed 's/^@//'); \
	nodes=""; \
	for d in hosts/*/; do \
		h=$$(basename $$d); \
		if [ "$$tag" = all ] || sed -n '/^  tags = /,/];/p' $$d/host.nix | grep -qw "$$tag"; then \
			nodes="$$nodes $$h"; \
		fi; \
	done; \
	cn=""; noncn=""; \
	for h in $$nodes; do \
		if grep -q 'geo.cities."CN' hosts/$$h/host.nix; then \
			cn="$$cn,$$h"; \
		else \
			noncn="$$noncn,$$h"; \
		fi; \
	done; \
	cn=$${cn#,}; noncn=$${noncn#,}; \
	if [ -z "$$cn" ] && [ -z "$$noncn" ]; then \
		echo "no nodes match $(TAG)"; exit 1; \
	fi; \
	status=0; \
	if [ -n "$$cn" ]; then \
		echo "=== CN (full push): $${cn#,} ==="; \
		nix run .#colmena -- apply --no-substitute --parallel $(DEPLOY_CN_PARALLEL) --on "$$cn" || status=1; \
	fi; \
	if [ -n "$$noncn" ]; then \
		echo "=== non-CN (substitute): $${noncn#,} ==="; \
		nix run .#colmena -- apply --on "$$noncn" || status=1; \
	fi; \
	exit $$status

FORCE: ;
