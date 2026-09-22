# Wiffaltro progression blueprint

Working design record for Phases 5–7. Started 2026-09-22 by explicit user direction.
**Current mode: design and decisions. No new progression implementation.**

## How this record works

This is the central workspace for the connected blueprint, discussed one piece
at a time. `SOURCE_OF_TRUTH.md` remains authoritative for approved game rules.
Existing research and catalogs are linked supporting material, not competing
plans. Phase numbers describe the eventual build sequence, not the order in
which we must finish design conversations.

Planning can proceed now while menu/sport QC remains open. Fix concrete reported
bugs when requested, but do not turn a design discussion into an implementation
sprint. Automated tests cannot choose the progression design or approve its feel.
Targeted prototypes may answer a named uncertainty later, with explicit scope.

For each piece: reconcile existing decisions, identify the actual open questions,
research where useful, present a reasoned recommendation and tradeoffs, discuss
with the user, then record their decisions. Do not batch every question into one
large questionnaire. Bring only the consequential choices for the current piece.

Use four explicit states:

- **Approved:** existing source rule or explicit user decision, with its basis.
- **Proposed:** recommendation awaiting a decision.
- **Open:** unresolved question, dependency or conflict.
- **Deferred:** deliberately outside the initial release/slice.

Numerical balance targets can remain provisional even when a system's purpose
and rules are approved. Preserve rejected/superseded decisions with their reason;
do not silently replace them. Reconcile newly approved rules into the source of
truth before implementation and link the decision ID here.

## Blueprint sequence

This is the starting discussion order. Revisit dependent pieces when later
choices expose a conflict; designing together does not mean freezing everything
at once.

| Piece | Decisions to settle | Completion record | State |
| --- | --- | --- | --- |
| 01. Season and career structure | What a season accomplishes; what resets, persists and unlocks; why the next run differs; how the three phases connect | One connected season-to-season flow and reset/persistence table | Open; next discussion |
| 02. Leagues and difficulty | League identities and initial access; overall tier pressures; unlock conditions; calendar difficulty versus selected tier | League/tier rules, availability and clear conditions | Open; existing direction approved |
| 03. Builds and category rules | Build directions; roles of Consumables, Bats, Ball Setups, Endorsements, Abilities, Pitches and temporary development; capacities and interactions | Category contracts, build goals and interaction limits | Open |
| 04. Economy and acquisition | Cash/Hype purposes and rewards; shop cadence/mix, prices, rerolls, sales; Free Agents and roster changes; consumable acquisition | Reward → acquisition → use loop and opportunity costs | Open; several baseline rules already approved |
| 05. Initial authored catalog | Exact effects, targets, triggers, duration, limits, stacking, rarity, provisional prices, tradeoffs, synergies/counters and acceptance criteria | Small coherent launch catalog with required hooks | Open; depends on 03/04 |
| 06. Opponents and season pacing | Club identities, rematch development, early/mid/late/playoff pressures and relationship to available player builds | Opponent development and calendar progression plan | Open |
| 07. Fields and stadiums | Venue identity/prestige, selected geometry variations, League/tier interaction, home building choices and Opening Day lock | Venue progression and home/away structural rules | Open; progression goal approved |
| 08. Persistent club and unlocks | Records/archive, collection, Club Funds, club identity, unlock paths and end-of-season handling | Career progression and persistent reward rules | Open; captain retention remains a future idea |
| 09. Player-facing flow | What players see/choose before, during and after games; information needed for builds, purchases, rules and unlocks | Screen/action flow, including save/quit/return expectations | Open |
| 10. Implementation blueprint | Actual authored-effect hooks, minimal definitions/state, saves/migrations, dependencies and bounded delivery slices | Reviewable engineering plan derived from approved design | Deferred until preceding contracts are coherent |

The first pass through 01–04 sets the shared structure. Catalog, opponent and
venue authoring must then inform one another; prices, upgrade budgets and new
field dimensions cannot be frozen in isolation. Career boundaries are established
in 01 and detailed in 08, so persistent systems are not an afterthought.

## Existing material and constraints

- `SOURCE_OF_TRUTH.md`: approved game/season/reset rules and roadmap.
- `LEAGUE_DIFFICULTY_ENRICHMENT.md`: existing League/tier proposals and compatibility
  considerations. Two starter Leagues, four tiers and championship unlocks are
  **proposals**, not user-approved counts or conditions.
- `FIELD_SCALE_AND_PROGRESSION_AUDIT.md`: field/proportion research and sensitivity
  evidence. Stadium progression is an approved goal; blanket 1.3× scaling is not.
- `ENRICHMENT_NOTES.md`: earlier ideas and unresolved questions to reconcile into
  the appropriate piece, without promoting them to approved rules by repetition.
- `IMPLEMENTATION_STATUS.md` and `VERIFICATION.md`: what exists and what has been
  checked. They are not records of human approval of gameplay or menu aesthetics.

Preserve readable pitching, meaningful player execution and understandable
scoring. Keep current sport tuning as the reference. Consumables still require
explicit inventory, activation, duration and targeting decisions. Temporary build
power resets at season end. Do not build a speculative modifier engine or career
unlock infrastructure before the authored rules require it.

## Decision log

| ID | Date | Decision | State / basis | Consequence |
| --- | --- | --- | --- | --- |
| BP-001 | 2026-09-22 | Shift the immediate workflow to a connected Phase 5–7 blueprint, developed and recorded piece by piece | Approved: explicit user instruction | Start design now; no new progression coding. Human QC remains open independently. |

## Piece 01: next discussion brief

First reconcile the existing run/reset/career rules into a compact flow:
**choose a season → draft/build/compete → season result → permanent progress → next season**.
Identify only the unresolved boundaries: what makes repeat seasons different,
what success and failure each carry forward, and how League access, difficulty
clears, collection and home-club development relate. Do not invent reward numbers
or reopen already-approved reset rules merely to fill the table.

Each subsequent approved decision receives an ID, the user's chosen rule, its
reason, affected pieces, outstanding numbers and source-of-truth references.
Implementation readiness is a later explicit decision, not an automatic result
of finishing a chapter or passing a test.
