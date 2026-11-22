#!/bin/bash
set -euo pipefail
mode=$1; fixture=$2; input=$3; sha=$4; request=$5; rows=$6
t="$(cd "$(dirname "$0")" && pwd)"
p="$t/$mode-$fixture"; mkdir -m700 "$p"; mkdir -p "$p"/{home,config,cache,data/godot/app_userdata/Wiffaltro}
file=$p/data/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json
test "$(sha256sum "$input" | cut -f1 -d' ')" = "$sha"
cp "$input" "$file"
while IFS= read -r key; do unset "$key"; done < <(compgen -e | grep '^WIFFALTRO_' || true)
exec env HOME="$p/home" XDG_DATA_HOME="$p/data" XDG_CONFIG_HOME="$p/config" XDG_CACHE_HOME="$p/cache" \
 WIFFALTRO_DYNASTY_ENGINEERING=1 timeout 445 "$W_GODOT" --headless --fixed-fps 60 --path "$t/project" \
 res://cp253_npc_benchmark.tscn -- "$mode" "$fixture" "$sha" "$request" "$rows" > "$p/scene.log" 2>&1
