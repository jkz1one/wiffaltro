# Detached Standard native draft continuation

Use Godot 4.6.3 with a **synthetic** CP286 primary-only fixture matching the
SHA-256 inside the probe. No original, live, or preexisting slot belongs in this
test. From the repository root, set `GODOT` to the official executable and
`CP286_FIXTURE` to the audited fixture, then run:

```sh
set -eu
: "${GODOT:?}" "${CP286_FIXTURE:?}"
proof=$(mktemp -d)
export XDG_DATA_HOME="$proof/data" XDG_CONFIG_HOME="$proof/config" XDG_CACHE_HOME="$proof/cache"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_STANDARD_CHAIN_OPENING=1
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$proof/project"
cp tools/qa/cp288_standard_continuation/probe.gd.txt "$proof/project/cp288_probe.gd"
cp tools/qa/cp288_standard_continuation/probe.tscn.txt "$proof/project/cp288_probe.tscn"
slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
mkdir -p "$(dirname "$slot")"
cp "$CP286_FIXTURE" "$slot"
"$GODOT" --headless --audio-driver Dummy --path "$proof/project" --editor --import
"$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path "$proof/project" res://cp288_probe.tscn
cmp "$CP286_FIXTURE" "$slot"
test ! -e "$slot.bak" && test ! -e "$slot.tmp"
```

The probe verifies the exact source, then performs one existing full native
closed-owner restore as part of constructing a detached Base draft. It
compares all three exact custody roots; it does not create a new Common
owner, write a new slot, or start any game. The once-carried Common fold,
earned rights, and Workshop draft are verified, not awarded by the probe.

The detached v4 CommonStart is permitted only as Standalone Base native
material. The production Common owner adapter rejects both capture and
hydration of that start dialect; no public command, save, archive adoption,
further season, or home activation is enabled.
