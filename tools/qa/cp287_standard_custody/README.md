# Inactive Standard archive custody proof

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
cp tools/qa/cp287_standard_custody/probe.gd.txt "$proof/project/cp287_probe.gd"
cp tools/qa/cp287_standard_custody/probe.tscn.txt "$proof/project/cp287_probe.tscn"
slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
mkdir -p "$(dirname "$slot")"
cp "$CP286_FIXTURE" "$slot"
"$GODOT" --headless --audio-driver Dummy --path "$proof/project" --editor --import
"$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path "$proof/project" res://cp287_probe.tscn
cmp "$CP286_FIXTURE" "$slot"
test ! -e "$slot.bak" && test ! -e "$slot.tmp"
```

This helper migrates the legacy three-root package into ordered bounded cut
bodies. Known legacy archive carrier strings are reinserted at checked byte
offsets; their textual surroundings are not regenerated. If the exact legacy
compression cannot be reproduced the migration fails. Each original root
still has its full exact size and digest. The helper obtains no native save
authority: even successfully unpacked bytes require independently authenticated
native lineage, proposal and close folds before any new owner can adopt them.

This version reads only the three legacy roots at this migration boundary.
The row layout separates body, ordered carrier locations, and full payload
identity for reuse, but a later flat-prefix carrier, bounded append rules,
and native admission are unimplemented. No new save format is read by the
game or written by the probe, and existing archive readers are untouched.
