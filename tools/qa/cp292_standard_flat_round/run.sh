#!/usr/bin/env bash
set -euo pipefail
godot="$(realpath "${1:?official Godot executable required}")"
start="$(realpath "${2:?synthetic CP291 human pending required}")"
base="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$base" rev-parse --show-toplevel)"
proof="$(mktemp -d)"
echo "$proof"
project="$proof/project"
cd "$repo"
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$project" > "$proof/assembly.log"
cp "$base/probe.gd.txt" "$project/cp292_probe.gd"
cp "$base/probe.tscn.txt" "$project/cp292_probe.tscn"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_STANDARD_CHAIN_OPENING=1
scope() {
  export XDG_DATA_HOME="$proof/$1/data" XDG_CONFIG_HOME="$proof/$1/config" XDG_CACHE_HOME="$proof/$1/cache"
  slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
  mkdir -p "$(dirname "$slot")"
}
native() {
  timeout "$2" "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp292_probe.tscn -- "$1" "$(sha256sum "$slot" | cut -d' ' -f1)" "$proof" "${3:-unused}" > "$proof/$1.log" 2>&1
  ! grep -E '^SCRIPT ERROR:|^ERROR:|^CP292 FAIL' "$proof/$1.log"
}
scope npc1
cp "$start" "$slot"
timeout 180 "$godot" --headless --audio-driver Dummy --path "$project" --editor --import > "$proof/import.log" 2>&1
native npc1 500
cmp "$proof/npc1-unpaid.json" "$slot"
cmp "$start" "$slot.bak"
scope npc2
cp "$proof/npc1-unpaid.json" "$slot"
native npc2 500
cmp "$proof/npc2-unpaid.json" "$slot"
cmp "$proof/npc1-unpaid.json" "$slot.bak"
scope settle
cp "$proof/npc2-unpaid.json" "$slot"
native settle 250
cmp "$proof/away-settled.json" "$slot"
cmp "$proof/npc2-unpaid.json" "$slot.bak"
scope paid-cold
cp "$proof/away-settled.json" "$slot"
native paid-cold 250 "$proof/npc2-unpaid.json"
cmp "$proof/away-settled.json" "$slot"
test ! -e "$slot.tmp" && test ! -e "$slot.bak"
