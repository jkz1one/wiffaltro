#!/usr/bin/env bash
set -euo pipefail
godot="$(realpath "${1:?official Godot executable required}")"
one="$(realpath "${2:?synthetic CP289 one required}")"
zero="$(realpath "${3:?synthetic CP289 zero required}")"
stage="${4:-chair}"
[[ "$stage" == chair || "$stage" == chair-resume ]]
base="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$base" rev-parse --show-toplevel)"
proof="$(mktemp -d)"
echo "$proof"
project="$proof/project"
cd "$repo"
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$project" > "$proof/assembly.log"
cp "$base/probe.gd.txt" "$project/cp290_probe.gd"
cp "$base/probe.tscn.txt" "$project/cp290_probe.tscn"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_STANDARD_CHAIN_OPENING=1
scope() {
  export XDG_DATA_HOME="$proof/$1/data" XDG_CONFIG_HOME="$proof/$1/config" XDG_CACHE_HOME="$proof/$1/cache"
  slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
  mkdir -p "$(dirname "$slot")"
}
native() {
  timeout 250 "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp290_probe.tscn -- "$1" "$(sha256sum "$slot" | cut -d' ' -f1)" "$proof" > "$proof/$1.log" 2>&1
  ! grep -E '^SCRIPT ERROR:|^ERROR:|^CP290 FAIL' "$proof/$1.log"
}
scope chair
cp "$one" "$slot"
cp "$zero" "$slot.bak"
timeout 180 "$godot" --headless --audio-driver Dummy --path "$project" --editor --import > "$proof/import.log" 2>&1
native "$stage"
cmp "$proof/chair.json" "$slot"
cmp "$proof/pending.json" "$slot.bak"
scope stock
cp "$proof/pending.json" "$slot"
native stock
cmp "$proof/stock.json" "$slot"
cmp "$proof/pending.json" "$slot.bak"
scope launch
cp "$proof/chair.json" "$slot"
native launch
cmp "$proof/chair.json" "$slot"
test ! -e "$slot.tmp" && test ! -e "$slot.bak"
