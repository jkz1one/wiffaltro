#!/usr/bin/env bash
set -euo pipefail
godot="$(realpath "${1:?official Godot executable required}")"
closed="$(realpath "${2:?exact synthetic CP295 closed primary required}")"
test "$(sha256sum "$closed" | cut -d' ' -f1)" = 5aa288a193cc438b37100c02773d308558b0ea1987d36bfa8421a87f26ed6d57
base="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$base" rev-parse --show-toplevel)"
proof="$(mktemp -d /tmp/wiffaltro-cp298-proof.XXXXXX)"
echo "$proof"
project="$proof/project"
cd "$repo"
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$project" > "$proof/assembly.log"
cp "$base/probe.gd.txt" "$project/cp298_probe.gd"
cp "$base/probe.tscn.txt" "$project/cp298_probe.tscn"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_STANDARD_CHAIN_OPENING=1
export XDG_DATA_HOME="$proof/data" XDG_CONFIG_HOME="$proof/config" XDG_CACHE_HOME="$proof/cache"
slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
mkdir -p "$(dirname "$slot")"
cp "$closed" "$slot"
chmod a-w "$slot"
stat -c '%s:%a:%y:%z' "$slot" > "$proof/stat-before"
"$godot" --version > "$proof/runtime.log"
timeout 180 "$godot" --headless --audio-driver Dummy --path "$project" --editor --import > "$proof/import.log" 2>&1
timeout 430 "$godot" --headless --audio-driver Dummy --fixed-fps 60 --path "$project" res://cp298_probe.tscn > "$proof/proof.log" 2>&1
! grep -E '^SCRIPT ERROR:|^ERROR:|^CP298 FAIL' "$proof/proof.log"
grep -q '^CP298 PASS detached projections and unchanged primary, no writes' "$proof/proof.log"
cmp "$closed" "$slot"
stat -c '%s:%a:%y:%z' "$slot" > "$proof/stat-after"
cmp "$proof/stat-before" "$proof/stat-after"
test ! -e "$slot.tmp" && test ! -e "$slot.bak"
