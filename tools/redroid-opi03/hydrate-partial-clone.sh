#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 /path/to/partial-clone [objects-per-batch]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage

repo=$(cd -- "$1" && pwd)
batch_size=${2:-5000}

[[ "$batch_size" =~ ^[1-9][0-9]*$ ]] || usage
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null

head_commit=$(git -C "$repo" rev-parse HEAD)
state_dir="$repo/.git/partial-clone-hydration-$head_commit"
missing_list="$state_dir/missing-objects"
manifest_marker="$state_dir/manifest-complete"

mkdir -p "$state_dir"

# A lazy checkout of the BPI Android monorepo can start hundreds of automatic
# repacks: every small promisor fetch crosses Git's gc.auto threshold again.
# Keep downloaded packs intact and defer one deliberate maintenance pass until
# the complete Android source tree has been built successfully.
git -C "$repo" config --local gc.auto 0
git -C "$repo" config --local gc.autoDetach false

if [[ ! -e "$manifest_marker" ]]; then
  temporary_list="$missing_list.partial"
  rm -f -- "$temporary_list"

  echo "enumerating objects missing from $head_commit"
  GIT_NO_LAZY_FETCH=1 git -C "$repo" \
    rev-list --objects --missing=print "$head_commit" \
    | awk '/^\?/ { print substr($1, 2) }' \
    >"$temporary_list"

  mv -- "$temporary_list" "$missing_list"
  rm -f -- "$state_dir"/batch-*
  split -d -a 6 -l "$batch_size" \
    "$missing_list" "$state_dir/batch-"
  touch "$manifest_marker"
fi

total=$(wc -l <"$missing_list")
echo "$total missing objects recorded; fetching at most $batch_size per request"

shopt -s nullglob
batches=("$state_dir"/batch-[0-9]*)
for batch in "${batches[@]}"; do
  [[ "$batch" == *.done ]] && continue
  marker="$batch.done"
  [[ -e "$marker" ]] && continue

  fetched=false
  for attempt in 1 2 3 4 5; do
    echo "fetching $(basename -- "$batch") (attempt $attempt/5)"
    if GIT_TERMINAL_PROMPT=0 git -C "$repo" \
      -c fetch.negotiationAlgorithm=noop \
      fetch origin \
      --no-tags \
      --no-write-fetch-head \
      --recurse-submodules=no \
      --filter=blob:none \
      --stdin <"$batch"
    then
      fetched=true
      touch "$marker"
      break
    fi
    sleep "$((attempt * 5))"
  done

  if [[ "$fetched" != true ]]; then
    echo "failed to fetch $(basename -- "$batch") after five attempts" >&2
    exit 1
  fi
done

echo "verifying that the locked commit is fully hydrated"
remaining=$(
  GIT_NO_LAZY_FETCH=1 git -C "$repo" \
    rev-list --objects --missing=print "$head_commit" \
    | awk '/^\?/ { count++ } END { print count + 0 }'
)
if [[ "$remaining" != 0 ]]; then
  echo "$remaining objects are still missing; rerun this script" >&2
  exit 1
fi

echo "partial clone is fully hydrated at $head_commit"
