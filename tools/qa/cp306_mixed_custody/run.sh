#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../../.." && pwd -P)"
here="$root/tools/qa/cp306_mixed_custody"
engine="$(realpath "${1:?verified official Godot 4.6.3 binary}")"
input="$(realpath "${2:?exact synthetic CP305 closed primary}")"
[[ "$(sha256sum "$engine" | cut -d' ' -f1)" == f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3 ]]
[[ "$(sha256sum "$input" | cut -d' ' -f1)" == 8549fcded318686355e1b0177f6186804f85438dbb832bbf0bda128d06c82dd5 ]]
[[ "$(df -B1 --output=avail /tmp | tail -1)" -ge 45088768 ]] # 40 MiB plus 3 MiB scratch.
stage="$(mktemp -d /tmp/wiffaltro-cp306-proof-XXXXXXXX)"
echo "$stage"
cp "$root/drafts/successor-dynasty-owner-v1/src/gameplay/season/successor_dynasty_owner_v1/starter_mixed_custody.gd.txt" "$stage/codec.gd"
cp "$here/probe.gd.txt" "$stage/probe.gd"
printf 'config_version=5\n[application]\nconfig/name="Wiffaltro CP306 Custody QA"\n' >"$stage/project.godot"
mkdir "$stage"/{home,data,config,cache}
status=0
(
  cd "$stage"
  env -i HOME="$stage/home" XDG_DATA_HOME="$stage/data" XDG_CONFIG_HOME="$stage/config" XDG_CACHE_HOME="$stage/cache" \
    "$engine" --headless --audio-driver Dummy --path "$stage" --script res://probe.gd -- "$input"
) >"$stage/native.log" 2>&1 || status=$?
cat "$stage/native.log"
[[ "$status" == 0 ]]
! grep -E '^(FAIL |SCRIPT ERROR:|Parse Error:)' "$stage/native.log"
