#!/usr/bin/env bash
set -euo pipefail
godot="$(realpath "${1:?official Godot executable required}")"
paid="$(realpath "${2:?synthetic CP294 paid required}")"
pre="$(realpath "${3:?synthetic CP294 complete unpaid required}")"
base="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$base" rev-parse --show-toplevel)"
proof="$(mktemp -d)"
echo "$proof"
project="$proof/project"
cd "$repo"
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$project" > "$proof/assembly.log"
cp "$base/probe.gd.txt" "$project/cp295_probe.gd"
cp "$base/probe.tscn.txt" "$project/cp295_probe.tscn"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_STANDARD_CHAIN_OPENING=1
scope() {
  export XDG_DATA_HOME="$proof/$1/data" XDG_CONFIG_HOME="$proof/$1/config" XDG_CACHE_HOME="$proof/$1/cache"
  slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
  mkdir -p "$(dirname "$slot")"
}
native() {
  timeout "$2" "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp295_probe.tscn -- "$1" "$(sha256sum "$slot" | cut -d' ' -f1)" "$proof" "$paid" > "$proof/$1.log" 2>&1
  ! grep -E '^SCRIPT ERROR:|^ERROR:|^CP295 FAIL' "$proof/$1.log"
}
scope hot
cp "$paid" "$slot"
cp "$pre" "$slot.bak"
timeout 180 "$godot" --headless --audio-driver Dummy --path "$project" --editor --import > "$proof/import.log" 2>&1
native hot 370
cmp "$proof/closed.json" "$slot"
cmp "$paid" "$slot.bak"
scope cold
cp "$proof/closed.json" "$slot"
native cold 370
cmp "$proof/closed.json" "$slot"
test ! -e "$slot.tmp" && test ! -e "$slot.bak"
