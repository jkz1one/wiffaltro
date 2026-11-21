# Common V4 Standard D1: qualification only

The private `owner_store.gd::qualify_standard_d1` entry checks the exact
admitted owner and current slot before projecting an intent. It writes
nothing and has no menu, factory, or Next connection. Neither the intent nor
a detached set of title flags is a birth or restore permission.

The qualification currently targets one exact positive case: the active
ordinary side is a just-closed Standard Base champion, with all 33 actual
results admitted by the existing ordinary reader, the complete native
receipt, and the matching latest common fold from that lineage. It refuses
an in-flight save transaction, a stale or mutated owner, unrelated title,
abandoned/incomplete season, unavailable next ordinal, or existing saved
Next proposal. The projected versioned intent includes the native Standard
D1 profile, exact source close and fold, championship proof, lineage, next
ordinal and seed. A future persistence step must bind these against the
authoritative admitted season before it clears the historical close on Next.
Do not treat a captured intent dictionary from callers as evidence.

Standard keeps its empty league rules. Native D1 pricing adds 1 to a positive
reroll quote after credits; zero still costs zero. The successor human Build
and five NPC Builds already have the matching native pricing adapters. Native
Standard D1 also includes venue policy: the detached pricing smoke does not
qualify venue admission, physical results, or D1 cold saves. The Standard
tactical AI `difficulty` value is not the career tier.

## Reproduce the isolated negative and pricing smoke

Assemble a new scratch project and use Godot 4.6.3 with separate scratch HOME
and XDG data, config and cache. No title fixture or player save is used.

```sh
python3 -B tools/assemble_successor.py /new/scratch/project --dynasty-owner
godot --headless --audio-driver Dummy --path /new/scratch/project --editor --import
cp tests/successor_standard_d1_intent.gd.txt /new/scratch/intent.gd
WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_DYNASTY_ENGINEERING=1 \
  godot --headless --audio-driver Dummy --path /new/scratch/project \
  --script /new/scratch/intent.gd
```

Expect `STANDARD_D1_INTENT_NEGATIVE_AND_PRICING_PASS`. The test creates only
one isolated Standard Base draft, rejects a caller-injected title, and checks
the exact Base slot is unchanged on strict read. It separately drafts four
picks in an unsaved pricing control and checks native human and all five NPC
markets. It does not manufacture or claim a championship.

## Next positive gate

First recover a checksum-verified generated **Standard Base champion V4**
checkpoint if one exists; otherwise start the ordinary Standard Base App on
a new isolated profile and use a bounded producer like the existing Dynasty
completion runner to supply controls only. Leave the original physical
workers and settlement in charge of scores, qualify the exact live title
through native Close, and retain verified generated checkpoints by round.
A lost playoff or eliminated season is valid evidence of that outcome, not
an entitlement; do not seed scores or substitute a native synthetic unit
fixture. Once that title exists, qualify intent, private four-pick
birth/Next and cold reopen before doing a full real D1 round/shop and D1
completion. No new D1 selector access is enabled here.
