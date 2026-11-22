#!/usr/bin/env bash
# Arguments must point to audited synthetic CP286 primary and CP280 backup.
set -euo pipefail
godot="$(realpath "${1:?official Godot executable required}")"
primary="$(realpath "${2:?synthetic CP286 source required}")"
backup="$(realpath "${3:?synthetic CP280 backup required}")"
base="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$base" rev-parse --show-toplevel)"
proof="$(mktemp -d)"
echo "$proof"
project="$proof/project"
cd "$repo"
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$project" > "$proof/assembly.log"
cp "$base/probe.gd.txt" "$project/cp289_probe.gd"
cp "$base/probe.tscn.txt" "$project/cp289_probe.tscn"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_STANDARD_CHAIN_OPENING=1
scope() {
  export XDG_DATA_HOME="$proof/$1/data" XDG_CONFIG_HOME="$proof/$1/config" XDG_CACHE_HOME="$proof/$1/cache"
  slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
  mkdir -p "$(dirname "$slot")"
}
scope write
cp "$primary" "$slot"
cp "$backup" "$slot.bak"
timeout 240 "$godot" --headless --audio-driver Dummy --path "$project" --editor --import > "$proof/import.log" 2>&1
timeout 240 "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp289_probe.tscn -- write "$(sha256sum "$slot" | cut -d' ' -f1)" "$proof" > "$proof/write.log" 2>&1
! grep -E '^SCRIPT ERROR:|^ERROR:|^CP289 FAIL' "$proof/write.log"
cmp "$proof/one.json" "$slot"
cmp "$proof/zero.json" "$slot.bak"
scope cold
cp "$proof/one.json" "$slot"
timeout 240 "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp289_probe.tscn -- cold "$(sha256sum "$slot" | cut -d' ' -f1)" "$proof" > "$proof/cold.log" 2>&1
! grep -E '^SCRIPT ERROR:|^ERROR:|^CP289 FAIL' "$proof/cold.log"
cmp "$proof/one.json" "$slot"
test ! -e "$slot.tmp" && test ! -e "$slot.bak"
timeout 90 "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp289_probe.tscn -- classifier "$(sha256sum "$slot" | cut -d' ' -f1)" "$proof" > "$proof/classifier.log" 2>&1
! grep -E '^SCRIPT ERROR:|^ERROR:|^CP289 FAIL' "$proof/classifier.log"
cmp "$proof/one.json" "$slot"
test ! -e "$slot.tmp" && test ! -e "$slot.bak"
