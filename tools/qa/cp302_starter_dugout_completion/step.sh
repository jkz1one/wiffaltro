#!/usr/bin/env bash
set -euo pipefail
root="$(realpath "${1:?exact QA export directory}")"
stage="$(realpath "${2:?existing disposable stage directory with copied slot}")"
mode="${3:?round, close or cold}"
want="${4:?verified exact primary digest}"
[[ "$mode" = "round" || "$mode" = "close" || "$mode" = "cold" ]]
[[ "$stage" = "$root"/* ]] # never accepts a player/original profile
mkdir -p "$stage"/{home,cache,config}
slot="$stage/data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
test ! -L "$slot" && test ! -L "$(dirname "$slot")"
[[ "$(sha256sum "$slot" | cut -d' ' -f1)" = "$want" ]]
out="$stage/$mode-$want.log"
test ! -e "$out"
env -i PATH="$PATH" HOME="$stage/home" XDG_DATA_HOME="$stage/data" XDG_CONFIG_HOME="$stage/config" XDG_CACHE_HOME="$stage/cache" \
timeout 1200 "$root/Wiffaltro.x86_64" --headless --audio-driver Dummy --fixed-fps 60 -- cp302 "$mode" "$want" > "$out" 2>&1
! grep -E '^(ERROR|SCRIPT ERROR|FAIL )' "$out"
echo "$out"
sha256sum "$slot"
