# CP299: native Standard-to-Dugout projection (no player entry)

The fixed read-only producer takes exact closed career bytes, strictly restores
them, and derives a native Dugout Base proposal and ordinal-two zero-pick draft
in memory. It derives the next seed from the authenticated ordinary lineage and
ordinal instead of taking a seed, target, basis or close receipt from the
caller. Seed 1002 is only the historical private writer parity control.
Both detached projections and serialization are shared by the existing private
Store writers. The candidate's archive points to the exact typed proposal bytes,
and native strict restore independently checks the encoded draft. The function
does not read the live slot, bind a Store owner, produce a write ticket, or
authorize any save. Existing private writer gates, CAS and readback still apply.

This is not a title unlock, menu, worker, new save version or release route.
The source Standard team reached the semifinal but earned no title. Standard
and Dugout are both starting leagues. The check plays no games.

To reproduce with official Godot 4.6.3 and the audited, generated CP170 and CP202 source/proposal fixtures plus the exact
pre-refactor activation produced on recovery commit `2bf303a` (never use a player
slot). The latter hashes to `79b5f3a63e687c736bd2a3c3860f865686d5e4b35c42fbd8a31cf7de893d9aff`.
The older rendered CP209 draft decodes identically, but is not a byte oracle:
its integral fields may be spelled as JSON floats, totaling 12 extra bytes.

```sh
set -eu
: "${GODOT:?}" "${CP170_CLOSED:?}" "${CP202_PROPOSAL:?}" "${PRE_REFACTOR_DRAFT:?}"
proof=$(mktemp -d)
export HOME="$proof/home" XDG_DATA_HOME="$proof/data"
export XDG_CONFIG_HOME="$proof/config" XDG_CACHE_HOME="$proof/cache"
export WIFFALTRO_DYNASTY_ENGINEERING=1 WIFFALTRO_ISOLATED_TEST=1
export WIFFALTRO_EARNED_LEAGUES_PREVIEW=1 WIFFALTRO_CROSS_LEAGUE_PREVIEW=1
python3 tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$proof/project"
cp tools/qa/cp299_starter_dugout_projection/probe.gd.txt "$proof/project/cp299_probe.gd"
cp tools/qa/cp299_starter_dugout_projection/probe.tscn.txt "$proof/project/cp299_probe.tscn"
slot="$XDG_DATA_HOME/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json"
mkdir -p "$HOME" "$(dirname "$slot")"
cp "$CP170_CLOSED" "$slot"
"$GODOT" --headless --audio-driver Dummy --path "$proof/project" --editor --import
"$GODOT" --headless --audio-driver Dummy --path "$proof/project" res://cp299_probe.tscn -- "$CP202_PROPOSAL" "$PRE_REFACTOR_DRAFT"
cmp "$slot" "$PRE_REFACTOR_DRAFT"
cmp "$slot.bak" "$CP202_PROPOSAL"
test ! -e "$slot.tmp"
```

The probe checks exact input digests, native strict reopen, full byte equality
against the fixed native producer for the derived seed, read-only review and
wrong/stale rejection, then repeats the two normal private writes with historic
seed 1002 in the disposable slot to prove that both historical outputs and
their exact backup bytes did not change.

The decoded historical comparison found no field-value differences. The six
lexical differences are under `ordinary_state.last_transition.basis`:
`common_sequence`, `ordinal`, `pennants.from_season`, `pennants.mastery_from`,
`pennants.version` and `seed`. The immediately preceding native writer, not
CP209's rendered lexical format, is the activation byte oracle.
