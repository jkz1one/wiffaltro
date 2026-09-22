# Enrichment ideas, not frozen rules

These notes preserve future options without authorizing implementation. The
current rules remain in `SOURCE_OF_TRUTH.md`.

## Season difficulty pacing, human QC follow-up

User feedback, 2026-09-22: pitching feels too good at the start, and the season
needs a more deliberate difficulty progression with games feeling increasingly
consequential approaching playoffs. Clarify whether the starting-power concern
means the player's pitching, opponent pitching, or both before selecting a lever.

Current code has a modest calendar ramp in AI pitch selection only:
`0.15 + difficulty * 0.25 + min(round_index, 9) * 0.025`. Standard goes from
0.40 in Game 1 to 0.625 in Game 10; playoffs use that same capped value.
This is an internal tactical weight, not a win probability or percent difficulty.
It influences locations and sequencing, not opponent batting execution, player
ratings, pitch physics or repertoire growth. Everyone starts with their authored
ratings/repertoire, and every game restores Stamina. There is no complete
opponent-development or playoff-difficulty system yet.

Proposal for the later design pass: distinct opening, midseason, stretch-run and
playoff stages, with recognizable opponent development and standings stakes.
Early pitching should leave useful room for seasonal builds; later opposition
should challenge execution and sequencing without unreadable trajectories or
automatic contact. Align opponent growth with the approved Phase 5 catalog;
full opponent development remains Phase 6. Do not infer balance from one homer,
inject rubber-banding, or lower all base stats without representative human QC.
No difficulty or rating changes are implemented by this note.

The follow-up recording revealed a left-handed spin inversion, now corrected
separately. Reassess the corrected pitches during human QC before using the
reported Four-Seam/Drop behavior as evidence for a difficulty or stat change.

## Captain retention, Phase 7 candidate

User idea, 2026-09-21: a mid/late-game achievement unlocks the option to keep a
team captain from season to season. The player can always let that captain go.
Their stats must return toward draft levels rather than retaining an ever-growing
seasonal build.

Preferred starting proposal for later evaluation:

- Keep the named character and attachment, not accumulated seasonal power.
- Reset to the character's authored draft stats; remove temporary Gear,
  learned seasonal power and other run-specific bonuses under normal reset rules.
- Retention occupies one of the four roster slots, not a free fifth player.
- Explicit Keep / Release choice at the season boundary; never mandatory retention.

Still open: the achievement, exact unlock timing, whether retaining replaces a
draft round or consumes another opportunity, and full reset versus bounded decay.
The user's partial-knockdown alternative remains on the table, but would need
tests against the no-permanent-universal-stat-power pillar. No captain flag,
unlock, carryover or rewards have been added in this pass.
