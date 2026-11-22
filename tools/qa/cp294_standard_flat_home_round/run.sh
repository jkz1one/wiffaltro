#!/usr/bin/env bash
set -euo pipefail
godot="$(realpath "${1:?official Godot executable required}")"
start="$(realpath "${2:?synthetic CP293 home pending required}")"
base="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$base" rev-parse --show-toplevel)"
proof="$(mktemp -d)"
echo "$proof"
project="$proof/project"
cd "$repo"
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$project" > "$proof/assembly.log"
cp "$base/probe.gd.txt" "$project/cp294_probe.gd"
cp "$base/probe.tscn.txt" "$project/cp294_probe.tscn"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_STANDARD_CHAIN_OPENING=1
scope() {
  export XDG_DATA_HOME="$proof/$1/data" XDG_CONFIG_HOME="$proof/$1/config" XDG_CACHE_HOME="$proof/$1/cache"
  slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
  mkdir -p "$(dirname "$slot")"
}
native() {
  timeout "$2" "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp294_probe.tscn -- "$1" "$(sha256sum "$slot" | cut -d' ' -f1)" "$proof" "${3:-unused}" > "$proof/$1.log" 2>&1
  ! grep -E '^SCRIPT ERROR:|^ERROR:|^CP294 FAIL' "$proof/$1.log"
}
scope hot
cp "$start" "$slot"
timeout 180 "$godot" --headless --audio-driver Dummy --path "$project" --editor --import > "$proof/import.log" 2>&1
native hot 750
cmp "$proof/home-settled.json" "$slot"
cmp "$proof/npc5-unpaid.json" "$slot.bak"
scope paid-cold
cp "$proof/home-settled.json" "$slot"
native paid-cold 330 "$proof/npc5-unpaid.json"
cmp "$proof/home-settled.json" "$slot"
test ! -e "$slot.tmp" && test ! -e "$slot.bak"
