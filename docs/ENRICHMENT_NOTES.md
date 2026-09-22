# Enrichment ideas, not frozen rules

These notes preserve future options without authorizing implementation. The
current rules remain in `SOURCE_OF_TRUTH.md`.

## Next design priority: League and overall difficulty progression

After the current human-QC presentation fixes, review
[`LEAGUE_DIFFICULTY_ENRICHMENT.md`](LEAGUE_DIFFICULTY_ENRICHMENT.md). It separates
accepted direction from proposed launch counts/unlocks, the authoring order and
the minimum future checkpoint contract. This prepares the next enrichment
decisions; it does not approve new gameplay systems or freeze the proposed numbers.

## Field size, proportions and stadium progression

User exploration, 2026-09-22: consider roughly 1.3× field/hitting scale, more
adult player proportions, and larger/grander later stadiums while preserving
the current pitching feel. The completed research recommendation is in
[`FIELD_SCALE_AND_PROGRESSION_AUDIT.md`](FIELD_SCALE_AND_PROGRESSION_AUDIT.md),
including 432 isolated Jolt trajectories and primary-source references.

Recommendation: retain current sport dimensions and hitting; change proportions
in a later graybox comparison rather than uniformly enlarging avatars. Let venue
prestige grow independently of field dimensions. Use selected larger parks as
strategic variation, not automatic scaling every game or in response to purchases.
Keep League rules, Difficulty pressure and venue identity separate. Preserve
between-season home remodeling and the Opening Day structural lock.

Human follow-up accepts field/stadium progression as a roadmap goal, now in
Source v0.4.28 §16/Phase 6. Larger/grander later destinations are part of the
direction; exact sizes, cadence and mechanical implementation remain unapproved.
The 1.3× experiment and avatar dimensions remain proposals, not adopted tuning.
League = Deck and overall Difficulty = Stake are explicit: start with a small
available League set and only Base unlocked per League. Higher tiers are earned
separately within each League. No exact unlock conditions or extra playable
Leagues have been invented; Backyard/Base is the current shell.

## Season difficulty pacing, human QC follow-up

User feedback, 2026-09-22: pitching feels too good at the start, and the season
needs a more deliberate difficulty progression with games feeling increasingly
consequential approaching playoffs. Clarify whether the starting-power concern
means the player's pitching, opponent pitching, or both before selecting a lever.

Current code has a modest calendar ramp in AI pitch selection only:
`0.15 + difficulty * 0.25 + min(round_index, 9) * 0.025`. Standard goes from
0.40 in Game 1 to 0.625 in Game 10 (now presented as Base for new runs);
playoffs use that same capped value.
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
