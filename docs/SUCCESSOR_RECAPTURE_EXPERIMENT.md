# Private row recapture experiment

Inactive additive owner113 only. It does not broaden ownership, migrate existing
saves, or replace owner112. Game109 and prior owner sources remain unchanged.
The running actual112 full-season test uses the already verified frozen112 source.

## Bounded change

One synchronous restore creates a local derived-row context. Decoder sync derives
the row with the unchanged full Build replay. Final recapture may reuse that
isolated row only when exact bounded operand bytes, digest, owner identities and
source signature match. All structural/progression/row validators and final
complete-envelope equality still run. Ordinary public capture and sync do not
use the context. Every public restore starts independently; no persistent memo
or trusted saved row is introduced.

See `drafts/successor-owner-recapture-v1/HANDOFF_SCOPE.md` for the deliberately
narrow lifetime, unsupported-graph fallback, and external Resource limitations.

## Native evidence

Godot 4.6.3 checks passed exact cached-versus-uncached encoded output on birth,
each of four draft picks, and a test-only reconstruction of the actual112
paid-round fixture. The original112 decoder first accepted that fixture;
public113 restore rejected its112 envelope. The diagnostic reconstruction is
not a shipped migration route or newly played113 game.

Mutation checks passed for contracts, book season key, progression counters,
result scores, player performance and roster without changing revision. Detached
copy poisoning, supplied-context reset, unsupported-object fallback and repeated
independent public restores also passed. Separate cold restore retained exact
113 bytes and unchanged, still-valid112 source bytes.

One ABBA diagnostic run measured private restore, excluding its subsequent
comparison capture:

| Mode | Trial 1 | Trial 2 |
| --- | ---: | ---: |
| Reused row | 21.030104s | 19.991894s |
| Uncached | 21.759254s | 21.912571s |

Means: 20.510999s versus 21.8359125s, approximately 6.1% lower in this small sample.
Each reused trial observed one original capture and one local hit. Another
headless season simulation was running concurrently, so this is diagnostic,
not a general performance guarantee. Twenty-second restores remain far from
interactive readiness. This experiment does not establish completed113 gameplay,
terminal113 behavior, full career carryover, Dynasty, visuals or a distributable.

A further cold process passed deliberate early-envelope and late-recapture
rejections with preseeded contexts: both returned null and cleared row, operand
bytes and digest; the late case performed original capture and a local hit before
exact-envelope rejection. Source113 gameplay remained unchanged during these
checks. Manifest byte/hashes, Python compilation and diff whitespace checks passed.
