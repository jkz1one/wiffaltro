# Pure successor player metrics

`player_metrics.gd` is an aggregate adapter, not an owner/history decoder or grant
authority. A caller must replay and validate the entire owner-bound career first.
It rejects structurally inconsistent successor progress through the existing
strict `CareerProgress.valid` contract. Structurally valid invented purchases or
scores are the caller's full-replay responsibility, not something metrics proves.

On a deep copy, validated successor progress is projected into the shared game's
historical-compatible aggregate representation. All games, null/unknown stats,
mastery and repertoire aggregates remain unchanged. Only recipe identifiers not
known to the historical validator are omitted from that private view. After the
unchanged shared metrics function runs, `season_lessons` is restored to the maximum
full successor lesson count. Nothing is serialized in the projected format.

All existing metrics and `ClubPlayerCatalog.earned` thresholds are reused. Null
progress remains unknown rather than fabricated zero-valued evidence. Completed
status on an unfinished proof is rejected. This does not itself certify receipts,
unlocks, completion, permanent ownership, Dynasty, or a full-season playthrough.

The focused test requires an actual isolated owned-round checkpoint copied to
`user://source-owned.json`; it first restores that checkpoint with owner111's
unchanged strict codec. It compares every shared aggregate and earned-player
result, tests null progress, rejects inconsistent catalog/version/recipe/player
strikeout/completion/extra-field data, and checks source preservation. Godot 4.6.3 qualification passed in isolated run `dlq3cu79`, including a clearly
synthetic nonlegacy-lesson operand, null-stat rejection, and original source-byte
preservation. This does not establish a played full season or persistent rewards.
