#!/usr/bin/env bash
# Run only in a disposable, preimported forward source project, never an installed profile.
set -euo pipefail
umask 077
if [[ $# -ne 6 ]]; then
  printf 'usage: bash run.sh GODOT FORWARD_QA_PROJECT HOME_PRIMARY CPU1_PRIMARY CPU2_PRIMARY NEW_OUTPUT_DIR\n' >&2
  exit 2
fi
here="$(cd -- "$(dirname -- "$0")" && pwd)"
editor="$(realpath "$1")"
project="$(realpath "$2")"
home="$(realpath "$3")"
first="$(realpath "$4")"
both="$(realpath "$5")"
output="$(realpath -m "$6")"
test -f "$project/project.godot" && test -d "$project/.godot"
mkdir -- "$output"
mkdir -- "$output"/{home,config,data,cache}
for kind in oracle settle; do
  for ext in gd tscn; do
    name="dynasty_fixed_step_$kind.$ext"
    test ! -e "$project/$name"
    install -m 0600 "$here/$name.txt" "$project/$name"
  done
done
export HOME="$output/home" XDG_CONFIG_HOME="$output/config" XDG_DATA_HOME="$output/data" XDG_CACHE_HOME="$output/cache"
timeout 400 "$editor" --headless --fixed-fps 60 --path "$project" res://dynasty_fixed_step_oracle.tscn -- "$home" "$first" "$both" "$output" 2>&1 | tee "$output/benchmark.log"
python3 -B "$here/compare.py" "$both" "$output" | tee "$output/comparison.log"
timeout 300 "$editor" --headless --path "$project" res://dynasty_fixed_step_settle.tscn -- "$home" "$both" "$output" 2>&1 | tee "$output/settle.log"
