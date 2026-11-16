# Successor owner-before-draft foundation

## Scope

This additive, inactive stage establishes a genuine fresh career before the first
Dugout draft pick. It does not adopt an already-played standalone season as a
career. The existing `src/`, original saves, standalone successor, and live League
successor are unchanged. Owner persistence uses its own slot and identity.

This is a bounded integration checkpoint, not a reduced final career design.
Owned gameplay, round settlement, later runs, earned permanent assets, unlocks,
Dynasty, visual playtesting, and a distributable build remain unqualified here.
Unsupported history and post-draft gameplay are rejected, not stripped from saves
or silently routed through the unowned runtime.

## Qualification

The isolated runner stages manifest-checked source into a temporary Godot project
and replaces HOME/XDG locations. It never opens the owner's original saves.

```
python tools/test_successor_signature.py --owner --godot /usr/local/bin/godot
```

Final Godot 4.6.3 isolated run: `/tmp/wiffaltro-signature-t476nele`.
Both `fresh-owner` and independent-process `fresh-owner-cold` passed against the
final six-file manifest, including shared-helper identity binding. Staged source
bytes were independently compared with the audited repository files.

An earlier complete preliminary run also passed at
`/tmp/wiffaltro-signature-agmzhr5f`, before the shared-dependency hash correction.
One earlier staging attempt stopped on a manifest mismatch during concurrent
source preparation, before native execution. The manifest was refreshed after
source freeze; no branch update or original save mutation occurred.

Assertions cover owner installation before pick zero, exact original starting
entitlements, genuine initial owned-player access, all four real draft choices,
separate opponent allocation, complete JSON replay and cold reopen at each draft
prefix. Negative cases alter seed, tier, active identity, earned flags, assets,
pending work, results, shop journal, rules and owner-source identity. A simulated
blocked temporary-save path verifies unchanged primary bytes and candidate state,
followed by an exact retry. The independent unowned League slot stays byte-identical.

The owner-source signature also binds reviewed shared fresh-start/access/asset
helpers. The test temporarily changes one helper only in the isolated staged
project, verifies the owner identity changes without changing Game109 identity,
and restores its exact bytes before persistence tests. This guards against an
owner identity that ignores its shared reconstruction code.
