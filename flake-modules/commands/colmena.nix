{ lib, pkgs, ... }:
''
  ACTION=$1; shift;
  if [ "$ACTION" = "apply" ] || [ "$ACTION" = "build" ]; then
    DEPLOY_ARGS=
    if [ "$ACTION" = "apply" ]; then
      # Always upload the closure from the deployment host. Target machines
      # must not contact a mixture of domestic and overseas substituters.
      DEPLOY_ARGS=--no-substitute
    fi
    ${lib.getExe pkgs.colmena} $ACTION \
      --eval-node-limit 5 \
      --parallel 0 \
      --keep-result \
      --show-trace \
      $DEPLOY_ARGS \
      $*
    exit $?
  else
    ${lib.getExe pkgs.colmena} $ACTION $*
    exit $?
  fi
''
