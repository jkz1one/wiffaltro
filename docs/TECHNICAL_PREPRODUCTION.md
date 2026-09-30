# Plastic-Ball Baseball Roguelite — Technical Preproduction

**Version:** v0.1.52
**Status:** FROZEN BASELINE WITH FIELD-SCORING / PITCHER-LANE AMENDMENT
**Scope:** Project architecture, Pitch simulation, batting/contact, ball-in-play, vanilla match, first Season Shell
**Companion doc:** `SOURCE_OF_TRUTH.md`

---

# 1. Technical Objective

## Shop-earned access and focused rerolls, 2026-09-30

Build23/schema27 adds nullable `order_start`, keeping build1–22 catalog fingerprints unchanged.
Its bool is inherited Special Order access; null disables prospective tracking for an older active
run. The paid-reroll count derives solely from successful ordinary `reroll` journal events whose
candidate actually spent Cash. It is copied through candidate/fork/commit and preserved through
draft build reconstruction. Third-reroll eligibility updates only after that stock is generated,
so subsequent new offers can include J01 without rewriting displayed stock.

Career4 stores nullable per-season `order_rerolls` evidence. It preserves preexisting version1–3
history with null evidence, validates bounds and binds the active run's inherited access and count
to exact season journal replay. Historical compact evidence is consistency data, not anti-cheat
proof. Abandonment preserves earned access; a new season starts a fresh count and no sponsor copy.
The same atomic save covers ownership, stock, Cash, career evidence and once-visit state.

`SeasonSpecialOrder` supplies eligible weighted pools and one `focused_reroll` transaction. It
reuses the ordinary RNG, price escalation, credit and payment authority, sampling without replacement.
The paid copy and unused-visit flag gate execution. Four stock positions are replaced, absent pool
positions are counted explicitly, and pack/recruit data remains untouched. Ordinary rerolls clear
exhausted-position display state but do not restore the focused allowance. Unsupported abilities,
transformations and offscreen AI buying remain gated. `SeasonSpecialOrderUI` exposes category
counts, exact transaction review, retained access and unavailable positions through existing shop
and Club Record controls. It also supports a legacy season with retained career but no paid build.

## Shared loadout lightbox and atomic live sales, 2026-09-30

`SeasonLoadoutUI` is a shared CanvasLayer component mounted by SeasonApp and by the shop's
Window. Its bottom-center entry reserves a44-pixel target and menu/footer space. Gear, Sponsors
and Supplies tabs share a bounded scroll body; Close stays outside the scroll. Modal focus stays
inside, Escape/outside clicks dismiss without forwarding an action, and closing a running match
releases GUI focus so Space returns to pitching rather than reopening the utility.

`SeasonLoadoutData` derives display rows from the existing ownership/catalog data without
writing a save. SeasonApp captures the detached paid wallet after pregame commitment and before
launching the match. Live supply rows merge held non-tactical cards with actual remaining match
copies, and report consumed copies separately. Local Legends uses the match-definition stamp
snapshot; Encore reads its live allowance. The projection deliberately avoids effect helpers
that can mutate runtime state. Exhibitions receive an empty seasonal snapshot.

During live inspection, the component preserves prior debug/tree pause flags, freezes actors,
lab updates and camera input, and blocks lab shortcuts. It cancels an uncommitted release before
opening. Closure and teardown restore the correct state. The final product-wide UI pass is
now an explicit user-required final slice; scope and native/human acceptance gates are recorded
in SOURCE_OF_TRUTH.md. This component is a functional candidate, not final art-direction approval.

Build22/schema26 adds replayed `match_inventory` and `match_sell` events. Pregame save records a
fresh attempt snapshot after the once-fixture grant. Sales validate exact owned receipts, fixture,
revision and first-release evidence, derive the existing refund from the paid copy and publish the
candidate only after a successful atomic save. A failed write rolls back the candidate and leaves
runtime effects unchanged. Existing restore migration preserves prior stock/catalog boundaries;
AI policy1 remains build19. No independent editable balance or attempt blob is saved.

`SeasonMatchSales` queues sold runtime copies until `can_change_defense()`. SeasonApp checks the
boundary and MatchState emits an inventory hook before the next batter's first pitch, preventing
a same-frame release from using stale modifiers. Only definitions change: player instances,
stamina, pitch counts, spent Encore and other resources remain intact. Paid ownership disappears
immediately, but the lightbox labels pending effects until retirement. A restarted attempt reads
only current ownership. Gear evidence keeps the exact first-release copies through settlement,
so sold Gear can earn completed-use progress without regaining ownership or Reclamation credit.
Current ownership determines subsequent sponsor income and stamps. Confirmation defaults to
Cancel, displays exact Cash before/after and reports failed persistence in the underlying modal.

## Prospective sponsor evidence, copy stamps and safe return, 2026-09-30

`SeasonSponsorProgress` freezes a validated starting `{hits, encore}` state and derives one
compact `{game, hits, win, multi_k}` row from each validated completed reward. Hit types use
credited batting lines for the club's current roster; two positive pitching-K lines satisfy
multi-pitcher evidence only when that game is won. Career3 stores nullable per-run evidence,
validates legal ordered club fixtures and score-consistent wins, and binds the active run to
exact journal replay. Historical compact evidence is save consistency, not anti-cheat proof.
Fork/commit/save retains the aggregate atomically. Failed saves cannot publish a career unlock.

Build21/schema25 adds `sponsor_start` and an earned-catalog fingerprint without changing any
prior signature or initial catalog. Null means no tracking for that active legacy run; a new
Working career run inherits prior access and starts prospective evidence. Old career1/2 rows
migrate with null sponsor evidence; no retrospective feat is inferred. AI market policy1 stays
at build19 with independent paid-stat acquisition. Eligibility filters only subsequent offer
generation, ordinary purchase and Wholesale; it never rerolls stored offers.

`SeasonLegends` derives stamp arrays from validated reward events and immutable purchase
receipts. No independent stamp blob is saved. Candidate pruning removes sold/replaced IDs,
including coordinated Wholesale changes; later purchases have new IDs and zero stamps.
Match definitions snapshot the count, preventing midgame growth. The shared swing adapter
adds one percent per stamp only to Contact fair-exit scaling, with the existing Bat/Deli and
Misc composition. `SeasonEncore` makes one narrow exception to ordinary no-return pitching:
validate the legal boundary and owned effect, temporarily clear the removed flag, call the
ordinary selection path, then consume the team allowance. Every other PlayerMatchState field
and tactical recovery record is retained. The default AI selection path is unchanged.

`SeasonEncoreUI` suspends lab updates/input while the explicit confirmation is open, starts
focus on Cancel, rechecks match/pitcher identity on acceptance and restores normal input on
close. Club Record and the owned-sponsor review expose prospective requirements, earned access
and exact-copy stamps. Automated UI/physics/save evidence is listed in VERIFICATION.md;
native visual review and human acceptance are separate outstanding gates.

## Receipt-derived Gear progression and catalog20, 2026-09-30

`SeasonGearProgress` binds a frozen per-season starting count map to completed-use records derived
from replayed reward commands. `gear_start:null` disables tracking; `{}` begins a new eligible
career at zero. The current build journal remains the authoritative purchase/use history, including
immutable copy receipts. No independent editable live counter is saved. Qualified Bat/Ball receipt
IDs are resolved to item identities after the existing Reclamation/performance validation; duplicate
rewards already fail before progression settlement. Fork/commit copies this aggregate atomically.

Build20/schema24 appends a separate earned catalog fingerprint while preserving build1–19 hashes
and their base Gear catalogs. `SeasonEarnedGear` holds only ten exact Working higher-tier candidates.
The shared slot/effect adapters handle them, and normal eligible Gear generation accepts only the
access list derived from the build's start counts plus its replayed local results. AI policy1 remains
pinned to build19 and its paid-stat-only market. `SeasonBuildRestore` extracts the existing decoder
and adds the version20 field check, keeping the main aggregate within the script-size gate.

Career extension2 adds nullable per-run compact `gear` evidence: ascending fixture IDs and up to
one Bat/one Ball identity each. Retained history validates legal player-club completed fixtures,
unique slots/games, known tracked identities and chronological tier prerequisites. The current
run's evidence must equal journal-derived use and its starting counts must equal prior retained
runs. Copies and prices remain in the current build journal; prior history keeps compact validated
use, not an entire archived shop journal or server-authoritative anti-cheat proof. Unknown fields,
unsupported IDs, fractional counts, mismatched baselines and altered current evidence fail closed.

Version1 career rows migrate to `gear:null`; older active builds stay untracked. New tracked runs
freeze prior retained counts before draft; final draft construction preserves this context. Whole
season save stages the career fork and publishes only after file replacement, keeping counters,
results, payouts and opponent purchases together. Failed result/replacement writes and retries
retain the existing transaction contract. Season abandonment closes the current proof while
retaining completed uses. The existing1024-run /8MiB guards remain in force.

## Atomic career extension and compact score history, 2026-09-30

`ClubCareer` is a version1 aggregate attached optionally to `SeasonState`. Its `runs` have
sequential club-local IDs, seed, explicit Standard/Base identity, status, compact score proof
and versioned receipt. `current` identifies the attached Working run, or0 when carrying the
ledger through a legacy season. Only a fresh, undrafted Working season with paid opponents
can start a tracked run. IDs never derive from seed. Maximum1024 retained rows rejects another
start without deleting history. Balance and Standard/Base clear are derived from receipts;
there is no separately saved mutable currency balance or manufactured permanent player set.

`ClubSeasonRecord` stores the six stable tiebreak draws and actual score tuples sorted by
fixture ID. Validation requires complete ordinary rounds and legal partial/full playoff
boundaries, distinct integer scores, the real regular schedule, standings-seeded semifinal
pairings and winner-seeded final. Completed histories require all33 league fixtures, including
already-supported offscreen results. Receipt version1 derives the actual finish and regular
wins; first-title25 is checked against preceding completed rows. It does not simulate a
historical game anew, depend on current player catalogs, infer player statistics or award
additional money for postseason wins. Active and abandoned runs require unfinished evidence
and empty receipts. Unknown fields, invalid current IDs and inconsistent rewards are rejected.

`SeasonSave.save` forks the career and stages synchronization/settlement before existing
whole-season validation. The career is added to the same JSON and published back to the live
season only after successful atomic replacement. Restore validates the ledger and requires
the current record's seed, status and exact full-precision normalized score proof to match the independently
restored current season. Existing build19/schema23 remain; optional `career.version=1` is a
separate extension. Older readers reject unknown fields. The bounded file limit becomes8MiB
to accommodate history. Backup recovery remains read-only until a successful later checkpoint.

`SeasonApp.begin_season` stages a candidate and a forked club. It closes the old run, settling
an already-complete run if needed, or recording an unfinished run as abandoned without pay.
It then starts the new Working ID or retains the ledger with current0 for legacy mode. On
save failure it restores the previous `SeasonState` reference and displays the error. It
refuses to overwrite unreadable existing primary/backup files when no prior state was restored.
Other ordinary checkpoints cannot mark abandonment. Exhibition and lab play never settle a
career. `ClubCareerUI` reads the committed ledger, pages20 records at a time, shows receipt
components and score details, and distinguishes earned Tier1 from currently playable Base.
No difficulty-controller, paid-pack, stadium editor or spending interface is added.

## Paid opponent ledgers and deterministic round settlement, 2026-09-30

`SeasonOpponents` owns five `SeasonBuild` aggregates, each seeded independently from the
season and initialized with its actual four-player roster, zero Cash and market1. Market0
retains human stock. `SeasonOpponentMarket` supplies only broad-stat loose offers and a
three-distinct-family fixed pack; all charges, caps, consumption and revisions still go
through `SeasonBuild.commit`. Build19 persists the market; human save validation requires0.
The existing build migration body moved unchanged into `SeasonBuildMigration` to retain
historical pool boundaries within the aggregate's lint limit.

`SeasonOpponentPolicy` fixes source-named profiles and roles. Highest Power chooses the hitter
(Contact tie-break), highest Pitching chooses the primary (summed active mastery tie-break),
Fielding chooses a distinct primary fielder, and Pitching chooses a distinct secondary;
remaining ties use ascending stable IDs. Distributed rotation uses lowest eligible stat then
ascending ID. Its objective/rotation cursor and paid-decision reasons are persisted. Policy1
omits unsupported mastery objectives and all non-stat market categories. It buys through
ordinary loose/pack/reroll operations, with no human-build argument or future-stock query.

`SeasonState.record_player_result` resolves all current-round scores before settlement.
Every participating AI receives its own base reward, then only survivors shop. Round10 uses
actual top-four standings; semifinal winners shop once before the final; elimination/final
pays without shopping. Auto-resolved AI-only playoffs call these same boundaries. Definitions
resolve through the owning AI build; `_make_team` uses its fixed primary pitcher/fielder.
`opposing_starter` is shared by lineup review and Film Room choices. Offscreen `_strength`
reads the current16 paid ratings instead of the frozen starting cache only for this cohort;
the existing score generator is unchanged. Old seasons retain frozen behavior.

New UI-created Working seasons opt in explicitly. `SeasonSave` schema23 includes the complete
opponent policy1 state. Restore reconstructs the draft and ordered results, deterministically
replays all five journals, then compares normalized JSON structures, including roles/cursor/
reasons. Both native in-memory save validation and parsed-file restore use the same numeric
normalization. There is no independently trusted mutable wallet/growth blob. The existing
atomic season file contains the human result and all AI transactions together; retry cannot
reward/shop again. No midgame save, offscreen event ledger, learned AI policy or league-tier
model is implied. The opponent UI reads this committed state without mutating it.

## Saved scouting and explicit pitch disclosure, 2026-09-29

Build18 derives `_scouts` from exact `scout` journal events (`game`, `recipe` and the normal
request/revision envelope). The operation is not in player-facing `SHOP_OPS`. It requires
active J08, a valid recipe, and an uncommitted/uncompleted fixture. Duplicate commands replay;
a new request cannot replace an existing selection. The existing pregame operation requires
a selection when Film is active. `SeasonSave` binds both event types to the appropriate
completed or pending fixture, and validates scout recipes against the announced opposing
starter. This is independent of the client's transient dropdown state.

`SeasonPregameCommit` stages scouting on the same fork as departure-credit expiry and Budget
Bites. Only a successful checkpoint exposes that candidate to match construction. The menu
stores a draft choice per pending game; a new season clears it. Committed games display the
locked recipe, not an editable dropdown. Pure `SeasonState.make_match` copies a saved active
Film target onto the owning `TeamMatchState` without mutation or automatic choice.

`MatchPitchDisclosure.present` runs immediately after `PitchFlightActor.start_pitch`, after
successful launch solving and execution. Its pure release filter requires the batting club's
active J08 snapshot and exact selected recipe. The event contains only source/recipe/throw/time;
no launch parameters enter the information channel. Human cue, `BatterApproachModel` recognition
state and `PlayRecord` export receive detached copies. `MatchState.begin_pitch` clears the
previous event; the existing approach reset clears recognition before the next delivery.
AI tracking accepts the disclosure as a separate optional argument. Existing prediction,
observation correction delay, RNG and swing decisions are unchanged. This establishes the
recognition channel, not a new AI purchase/choice or prediction policy.

Catalog11 adds only J08. The `film_from` gate activates next visit for older journals.
Catalog-version selection moved into `SeasonSponsorCatalog.for_visit` with the same ordered
historical boundaries, keeping the build aggregate within its existing lint limit. Save
schema22 retains historical catalog signatures and earlier Budget events without rewriting
their shape. Neither replay nor loading invents a scouting choice for an old committed game.

## Pregame checkpoint and once-fixture supply grant, 2026-09-29

Sponsor catalog10 adds Budget Bites. Build17 stores the next-visit `budget_from` migration
gate, while `_pregames` is derived solely by replaying `pregame` journal events. The command
contains only fixture identity and the normal request/revision envelope. It is deliberately
absent from player-facing `SHOP_OPS`. `SeasonBudgetBites` derives active ownership, actual Cash
and shared capacity, records one outcome (`inactive`, `cash`, `full`, `granted`) and snapshots
the committed Cash. The internal fixed Plan grant uses `budget:<fixture>` with paid0 and no
wallet credit. Existing ownership candidate validation still enforces final held capacity.

Every current Working-season Play Game commitment records the check, including absent sponsors
and failed eligibility. This prevents buying the sponsor, spending down or freeing space after
a first unfinished start from retroactively creating a grant. Existing exact-request replay
is idempotent; another request for that fixture is rejected. Completed reward identity also
blocks past-game commitment. Pure `SeasonState.make_match` remains a side-effect-free bridge.

`SeasonPregameCommit.save` forks the build, applies any existing departure-credit expiry,
records the once-fixture check if needed, and saves the season before exposing the candidate
or launching the lab. It temporarily assigns the candidate for the existing save validator,
restoring the prior build if persistence fails. This combines steps that previously saved
credit expiry and pregame separately. Legacy/non-Working paths retain their normal checkpoint.
Existing pack/readiness guards remain. The lineup page reads derived eligibility/history;
viewing, leaving or editing that page performs no grant.

Schema21's history validation walks pregame and reward events in order. A pregame ID must match
the next corresponding completed player result or the actual current pending fixture. Unknown
future-game grants cannot be made valid by presenting a structurally well-formed build journal.
No separate editable inventory or grant-flag save blob is introduced. The ordinary tactical
ledger handles activation/consumption; exact paid0 copies can carry, discard or exchange under
existing rules. This does not serialize or retain unfinished in-match effects.

New tests cover Cash0/4/5, mixed development capacity, retry/no-queue rules, late sponsor buying,
old paid J07 migration, actual grant-review/Play Game input, failed checkpoint rollback, restart,
discard, exhibition exclusion and fixture-order tampering. Two physical games separately use
and carry a generated Plan through ordinary AI swing and completed-result/reload paths. AI
buying/activation policy, native visual and human balance acceptance are still open.


## Tactical sponsor exchange and paired activation, 2026-09-29

Sponsor catalog9 adds E07/J07. Build16 stores `tactical_sponsor_from`; schema20 validates it,
preserves catalog1–8 fingerprints and enables the new pool next visit. The catalog's explicit
build-version mapping replaces the prior nested signature expression without changing old
version results. The existing paid sponsor/Wholesale routes handle acquisition and replacement.
`SeasonSponsorEffects.snapshot` copies E07 eligibility only for the owning roster.

`SeasonTacticalExchange` owns the explicit four-type allowlist, current type eligibility,
active J07 requirement, exact source receipt, derived list-price difference and `mix_used`
visit flag. The aggregate command accepts receipt and target identity, never a client price.
An internal ownership exchange removes/adds one held copy and debits the difference inside
its candidate state; final capacity and Cash validation still apply. The source's historical
paid amount never creates a refund. Output `paid` is the exchange's actual incremental debit.
Rerolls and sponsor replacement preserve the visit flag; opening a genuinely new shop resets
it. The ordinary shop preview/candidate/save boundary commits both inventory and the flag.

`MatchTactics.activate_combo` first validates both exact copies and the shared readiness/role
rules. It then records Tape and Plan on the same PA with `combo: true`, consumes both, locks
the swing and spends `_combo_used`. No intermediate event-loop yield exposes a partial pair.
The `A10+C03` runtime marker selects both existing multipliers and Plan's lock. It is an effect
marker, not an owned item. The Contact ellipse now recognizes both ordinary Tape and the pair.
`MatchTacticalControls` provides dedicated Contact/Power pair choices, bounded scrolling review,
exact-copy/stale-player rejection, cancellation and a visible active pair/lock.

`SeasonTacticalCombo.valid` restricts completed consumption to one ordered Tape/Plan pair,
active E07 ownership and the same player/PA. Existing settlement validates all exact fields,
receipts, participation, swing and PA bounds; only the proven second paired record can share
the previous PA number. Old formats reject pair evidence. Completed-game result/journal
agreement and atomic consumption use the existing persistence path, not a new save blob.
No box-score evidence is claimed to reconstruct every historical readiness event.

Contract/UI tests exercise all sixteen exchange type combinations, full capacity, insufficient
Cash, invalid inputs/outputs, repeat-use protections, old migration and actual saved clicks.
Both swing choices run through actual contact resolution and whole paid physical games with
shared AI execution, corrupt-ledger rejection, unfinished restart and failed-save retry.
The test driver makes explicit choices; autonomous AI shopping/activation remains absent.
Native visual and human balance acceptance remain separate open gates.


## Expanded tactical pool and consumable scoring, 2026-09-29

`SeasonTacticalCatalog` keeps the three-card v1 catalog/signature immutable and adds a v2
pool with Heat/Base. Build15 records `expanded_tactical_from`; schema19 restores prior shops
and rerolls exactly and activates the expanded generator next visit. Buy and Wholesale both
check the versioned eligible catalog. Ownership uses all supported identities while retaining
exact-copy provenance, shared capacity and no resale. Old build14 fingerprints remain valid.

`MatchTactics.pitch` duplicates only a heated pitch recipe, multiplying its already-rated
velocity parameter before `PitchAimSolver` and ordinary execution/fatigue. It binds the actual
active `PlayerMatchState`. `TeamMatchState.select_pitcher` clears Heat on a real index change,
so a zero-pitch starter's legal return cannot revive it. Existing PA scope and consumption
history remain authoritative. Both human and AI deliveries use the same launch hook.

`TacticalBaseAdvance` selects the first occupied base and rejects an occupied destination.
It moves exactly that identity or calls `MatchState._add_runs(1)` from third. It does not call
PA/stat completion. The consumed ledger adds exact `advance = {runner, from, to}` evidence.
Settlement validates that shape, current roster and actual runner hit/walk participation;
Heat/Base allow activation on the final uncompleted readiness PA. Format15 also allows that
PA bound for Recovery, which may precede an opponent's Base walk-off. Previous formats keep
their old bounds. This is structural/box-score integrity, not historical base-state replay.

`MatchTacticalControls` reviews Heat's pitcher or Base's exact runner/destination and rejects
stale confirmation. It refreshes markers/status after movement and directly begins the
idempotent normal outro on a pre-pitch walk-off. `SeasonApp` still automatically records the
ended game; fault tests must inject write failure before activation, not after its process
loop has already saved. Retry persists the settled result without consuming twice.

The new contract/UI suite covers all eight occupancy patterns, paid stock, schema18 migration,
substitution lifetime and108 physical pitch combinations. Two additional whole games cover
paid Heat/Base use, actual launch telemetry and exact consumption replay. Headless viewport
input/layout is not rendered visual approval; no AI shopping/activation policy is inferred
from explicit test-driver choices.


## Tactical inventory, match use and result settlement, 2026-09-29

`SeasonTacticalCatalog` defines three Working held items with no resale. `SeasonBuild` format14
adds exact `tactical_buy` commands, a catalog signature and `tactical_from` next-visit gate.
`SeasonGearCatalog.offers` accepts an optional tactical pool; historical callers default to
empty, preserving prior random draws and frozen shop/reroll histories. Existing fixed packs
and development targets remain unchanged. `SeasonTacticalPurchase` uses ordinary bank receipt
and capacity authority, never client-provided price or effect values.

`SeasonState.make_match` copies only the owned tactical receipts into the season player's
`TeamMatchState.tactics`. `MatchTactics` validates club identity, pre-first-pitch phase, role,
receipt, once-club/PA use and once-pitcher/game recovery. Activation removes one detached copy
and records receipt/player/global PA/swing atomically with its temporary effect/resource
change. PA-number scoping and GAME_END guards clear benefits without erasing consumed history.
Stamina maximum is initialized at match creation and remains unchanged during the game.

`SeasonSponsorEffects.swing` composes Tape after existing Gear/Optics/Deli; the returned
resource copy preserves authored assets. `ContactResolver` applies Plan's quality-gated
multiplier only inside the fair-contact branch. `PitchBatLabSwingSupport.begin_swing` rejects
the unchosen swing before consuming a swing attempt. The AI execution path selects the locked
profile while keeping its existing pitch-reading decision. No autonomous tactical purchasing
or activation policy is enabled; full-game test drivers make explicit synthetic choices.

`MatchTacticalControls` adds a readiness entry and bounded, scrolling confirmation dialog.
It checks the existing readiness/presentation/release guards, exact PA and reviewed player;
parent match input is blocked while the dialog is open. No separate gameplay pause state is
introduced. The active effect/lock persists on the entry and Tape uses the modified outline.
Shop acquisition and discard use the existing preview/candidate/save boundary. Wholesale
permits duplicate tactical identities only on distinct offers; trusted discounted held
purchases are restricted to this catalog and cannot stack with development concessions.

`SeasonApp._commit_result` forwards the paid club's consumed ledger. Format14 reward replay
validates exact owned tactical receipts, chronological PA bounds, completed participation,
chosen swing and per-pitcher recovery limits, then discards those receipts within the same
candidate as income and statistics. Schema18 stores the evidence in both the reward journal
and matching fixture result, requiring exact agreement. Box-score validation does not prove
historical pitch-by-pitch timing; live runtime guards enforce that timing. Unfinished restart
restores the pregame snapshot with no effects retained; failed completed-result writes retry
the already-settled in-memory result once, or reload the intact pregame checkpoint.

Tests cover real paid stock, shared/duplicate capacity, Wholesale, old migration, actual
viewport clicks, bounded dialogs, stale target rejection, resolver quality/fair gates and
whole physical games. Native rendering and human acceptance remain separate open gates.


## Atomic Wholesale transaction and receipt provenance, 2026-09-29

`SeasonWholesale` derives exact supported destinations from current offers and ownership.
The client submits two target dictionaries and the discounted offer identity, never prices.
The helper rejects mixed categories, same identity/slot, duplicate replacement receipt,
invalid targets and discounts assigned to a dearer item. All operations occur on the existing
SeasonBuild candidate, whose enclosing checkpoint publishes only after successful saving.

Both explicitly selected OLD receipts sell before either acquisition, allowing their proceeds
to finance the total. Gear sales retain Reclamation's exact-copy hook; sponsor removal clears
its scholarship instance. New Gear/sponsor purchases receive distinct transaction IDs and a
trusted `wholesale_discount` bounded by min(4,floor(base/4)); it cannot coexist with the held
Development credit. SeasonOwnership records actual payment. No temporary owned spare exists.
Lessons use separate growth IDs but one combined charge, preserving exact personal mastery
and final repertoire validation. The once-visit flag is journal-derived and survives rerolls.

`SeasonWholesaleUI` provides offer selection, exact destinations, equal-price receipt choice
and final combined review. Existing scroll bounds, cancellation and failed-save rollback apply.
The fixed student and both lesson replacements appear before confirmation. Supported categories
are deliberately limited to implemented normal single-item routes; no tactical/ability stock
is fabricated. Build13/schema17 adds `wholesale_from` and catalogue8 while freezing earlier
catalogues and preserving the old paid shop's generation through same-visit rerolls.



## Cornerstone commitment and stationary resolution, 2026-09-29

`SeasonCornerstone` validates the owned pre-PA selection and qualifies its0.12 margin.
`MatchState.cornerstone_anchored` defaults false and resets on completed appearances.
The existing first-pitch cancellation boundary is retained. Human anchor selection and
AI anchor assignment refuse position changes while the chosen PA is locked. Release-meter
and presentation gates additionally prevent stale UI actions from changing the selection.

`FielderController.begin_play` receives an optional stationary flag only for owned anchored
fair contact. Stationary physics advances the normal reaction timer but never moves toward
an intercept or stale target. `FielderPlanner.plan` has a default-false stationary parameter;
its reach prediction cannot assume travel when true. Controller targets remain the legal
anchor. The bonus requires the normal reaction timer and nonnegative reaction margin;
actual attempts retain ordinary reach/height and resolver difficulty checks. End play clears
the controller flag, and new matches clear both runtime and PA state.

Primary resolution moved into `PitchBatLabDefenseSupport.try_primary`, retaining the lab's
call interface and ordinary outcome path. The stationary initial-reaction gate and post-
eligibility bonus are its only new behavior. Courier remains an independent grounded margin;
PitcherDefense receives no Cornerstone term. Foul launches pass stationary=false and no bonus.
The main lab is not globally reformatted, preserving its Godot warning-annotation syntax.

MatchSponsorControls adds a focusable FIELD-panel button, lock disclosure and active menu cue.
Paid sponsor previews use the shared purchase/replacement/resale and atomic checkpoint paths.
Build12/schema16 adds `anchor_sponsor_from`; sponsor catalogues1–6 and old fingerprints stay
frozen. No persisted independent choice blob, earned access, AI shopping or new rating is added.
`SeasonSchoolSponsors.has_pair_targets` also checks distinct eligible players before offering
an Open Book pair, preventing a one-learner UI dead end while preserving single purchase.


## Development sponsors and atomic concessions, 2026-09-29

`SeasonSchoolSponsors` derives E06 triggers from actual completed-game `h` statistics,
F04 visit use from the build journal, and J10 fixed-student/use state from exact sponsor
purchase receipts. No independent editable allowance blob is saved. Pending Union earnings
become spendable only when the existing eligible shop route opens. `leave_shop` clears
both Union and Reclamation credits; saved visit allowances stay consumed. Final/eliminated
season histories cannot accept later shopping operations.

`SeasonDevelopmentPurchase` retains old purchase request IDs and pre-build11 bank journal
shape. New held purchases pass a trusted bounded acquisition discount into SeasonOwnership,
which records the actual paid price. Callers cannot submit their own discount amount through
the build API. Immediate purchases, growth, offer consumption and chosen allowance settle
on one fork. A failed candidate or disk write publishes none of them. Fixed-pack acquisition
uses Union credit once; later selection/skip and held use never enter the discount path.

F04 has two separate exact development targets and journal IDs within one transaction.
It validates both and charges the combined price before publishing. J10 records the purchased
receipt's student and three uses; the third successful subsidized purchase or actual student
replacement retires that same receipt at zero resale. Manual sale/replacement clears its
progress. Student nomination and overlapping concessions have explicit UI screens, while
review shows actual Cash, remaining uses, exact lesson recipients and personal mastery.

Build11/schema15 adds `school_sponsor_from` and catalogue6 while preserving catalogues1–5.
Old paid saves replay before migration, retain current stock/rerolls and activate the new
pool only next visit. Derived scholarships are copied with candidate forks and rebuilt from
events on restore. E06 acquisition mapping and J10 zero-nonbaseline eligibility remain
explicitly unapproved Proposals. No AI acquisition or offscreen hit attribution is added.


## Used Gear and transactional reroll credit, 2026-09-29

`MatchGearUsage` captures detached paid receipt IDs on the first actual recipe-bearing
release through MatchState's existing launch notification. SeasonState configures the
player club's equipped receipts, independent of which team pitches first; midgame shopping
remains prohibited. Abandon/restart produces a new empty usage record. Only completed
SeasonApp settlement passes the first-pitch evidence into the reward journal/result.
The existing recorded-versus-saved retry flags prevent duplicate completion on save retry.

`SeasonReclamation` validates at most three distinct receipt IDs against the current paid
loadout and nonempty validated completed-game performance. SeasonBuild derives `_used_gear`
by replay, never from a standalone editable used flag. Sale removes that receipt's use
state. Successful sale/replacement alone can award a visit credit; failed candidates never
publish their wallet, use or credit mutation. Sponsor ownership is checked at sale time.

Visit fields `reclamation_used` and `reroll_credit` are derived from journal events and
retained through forks/replay. Ordinary reroll charges base minus credit, then clears it
while preserving the escalating counter. `leave_shop` clears only the unused credit, not
the visit allowance or offers. Back/window close and direct game-start paths checkpoint
expiry before departure; a failed write retains the shop and credit. Open packs keep their
existing resolution requirements. Credit is excluded from every purchase budget.

Build10/schema14 adds sponsor catalogue5 and `shop_sponsor_from`. Prior catalogue hashes
and current-visit generation remain frozen. Saved result receipt evidence must exactly
match its reward event, whose replay checks actual ownership; foreign/duplicate evidence
is rejected. Reconstructed history cannot grant usage merely from a final score. Existing
older games preserve their old state rather than retroactively qualifying Gear. No AI
acquisition, offscreen release fabrication or permanent item inventory is introduced.


## Field sponsors and Contact shape selection, 2026-09-29

SeasonSponsorCatalog generation4 adds F02/F03/G04 without altering generations1–3.
SeasonBuild9 journals `field_sponsor_from`; schema13 validates/replays old builds and
migrates only missing eligibility gates. Paid active ownership still produces detached
player-definition match snapshots. No independent sponsor state is accepted from a save.

MatchState stores the current `optics_mode`, resetting it on every completed PA.
SeasonSponsorEffects validates the existing between-batters boundary and ownership;
MatchSponsorControls further gates the human control by readiness, PRE_PITCH, presentation,
pause and uncommitted AI selection. A focusable button cycles neutral/wide/tall. Its cyan
unit-circle mesh is scaled by the exact Gear-then-Optics Contact radii; the existing marker
parent applies the ordinary Contact rating factor. Only owned Optics replaces the old
Contact rectangle. Power and unowned baseline presentation remain unchanged. Actual human
and AI swings already share the modified profile path; no future-pitch data informs choices.

FieldingResolver accepts an optional final control-margin adjustment after physical gates
and existing positive handling-difficulty scaling. Only the Primary Fielder grounded hook
passes Courier's−0.08; PitcherDefense remains a neutral caller. TagAdvanceResolver receives
separate gather/travel scales through the existing caught-air/non-third-out hook, identifies
the actual catcher, and uses the batting club's Trainers. Its result exposes effective times
for contract tests and on-screen explanation. The extended tag result uses18-point event
text to retain all lines inside the existing panel; ordinary event sizing stays unchanged.

Tests cover real viewport mouse/keyboard selection, shape locking/reset/ownership, ellipse
scale, paid UI/rollback/reload/resale, old paid schema12 migration and frozen rerolls,
marginal live tag outcomes for both catcher roles, ground/third-out exclusions, actual
empty-base Primary control and neutral Pitcher ground control. A tenth complete physical
game combines these three sponsors with existing Gear; its synthetic opposing ownership
and explicit pre-PA choices are test fixtures, not implemented AI purchase/choice policies.


## Actual pitch-cost ledger and Strikecraft, 2026-09-28

`MatchPitchLedger` stores only the first three distinct recipe IDs/costs per pitcher in
the current PA. Stable player ID partitions attribution; successful-release pitch count
rejects duplicate notifications. Empty legacy notifications, canceled releases
and nonfinite/negative costs do not contribute. Cost/recipe arrays returned to callers
are detached. Every completed PA clears the ledger; its memory is bounded by the roster
and three stored recipe occurrences per participant.

The physical launch path records stamina before/after the existing spend only after a
valid launch is built. `MatchState.note_pitch_released` preserves Bullpen Kit participation
and supplies exact recipe plus actual removed stamina to the ledger. Old no-argument
callers preserve participation without inventing recipe/cost evidence. On a credited K,
SeasonSponsorEffects evaluates B03 before PA cleanup and restores at most6/25% of eligible
costs. TeamMatchState owns per-game usage and actual-refund totals, so another pitcher or
inning cannot renew the shared allowance. A zero-cost qualifying K still uses one of the
two qualifying trigger slots. No new pitch or statistic event is emitted by recovery.

Build8 uses sponsor catalogue3 and `sequence_sponsor_from`, leaving catalogue1/2 immutable.
The restore pipeline now calls one idempotent `SeasonBuild.migrate()` that retains every
already enabled gate and initializes only missing pools to the next visit. This replaces
seven scattered public migration entry points without changing old journals/generators.
Schema12 validates all historical format boundaries and preserves paid-copy receipts. No
live PA/recovery state is stored independently in a season save: leaving/restarting a match
returns to its pregame build, as before. Actual game completion still settles only supported
income sponsors. The UI and runtime distinguish recovery from settlement Cash.


## Match sponsor effects and provenance, 2026-09-28

Build7/schema11 adds a second sponsor catalogue generation without altering the frozen
build6 income definitions/hash. `gameplay_sponsor_from` freezes existing visits, including
rerolls, until the next shop boundary. Catalogue access in ownership, offers and UI now
supports both generations; income settlement still uses only the explicit three-income
allowlist. No independently editable sponsor-state blob is added to a save.

`SeasonDevelopment.earned_players` derives distinct qualifying current IDs from validated
stat/mastery/round_out journal events. Recruit and learn events are excluded. SeasonBuild
attaches runtime-only sponsor metadata to current own-player clones, after Gear; former
players and opponents receive none. College's count is recomputed on each definition build,
so committed growth, roster changes, sale and returning-instance history cannot leave a
stale count. Authored resources and existing player/save fingerprints stay unchanged.

MatchState tracks a pending next-batter Single flag from the finalized hit enum, independently
of the display description. Every completed PA replaces it, and half transitions clear it.
SeasonSponsorEffects combines that flag with paid A07 metadata and the actual Contact profile.
It adds0.04 to the Bat exit factor while retaining the separate Misc exit multiplier. The
existing contact resolver applies that final scalar only after quality/outcome resolution
and only to fair contact; no duplicate contact path or result override is introduced.

College compares stable delivery IDs, then multiplies the pending successful-release cost
by1−0.03×min(4,earned players). The established launch-validity gate still controls spending.
Gear, effort and release overdrive retain their existing once-only composition. Match metadata
is derived from the season journal and discarded with the match. Both control paths share
these hooks; synthetic AI-equipped tests do not enable production AI shopping or offscreen
benefits. See VERIFICATION.md for contract, UI, migration and whole-game evidence.


## Paid sponsor settlement, 2026-09-28

Build6 adds a versioned sponsor catalogue fingerprint and next-visit migration boundary,
while preserving all previous Gear signatures and generators. The mixed-offer generator's
optional sponsor pool defaults empty, retaining exact old draws. Enabled sponsor entries
use source rarity weights, exclude active identities, and cannot repeat within a visit.

Sponsor purchases/sales delegate to the existing active-only ownership journal through the
aggregate candidate fork. Explicit replacement validates the full resulting wallet/loadout
before checkpointing. No new reserve storage or midgame sale path is introduced. Three
supported identities cannot yet fill all five slots; capacity-changing sponsors remain later
work rather than synthetic production items.

For new-format results, SeasonState passes the actual completed game's performance snapshot
into the reward command. SeasonSponsorCatalog derives bounded earnings for current roster IDs
from bb, p_k and distinct credited extra-base types. Valid nonempty statistics are required
to earn money; absent evidence returns zero. Base reward and derived income settle within one
candidate commit. Derived per-game breakdowns survive forks/replay without an independently
editable saved balance. SeasonSave validates journal performance against the corresponding
fixture result after reconstructing historical roster membership. Old rewards retain their
original shape, and loading alone never rewrites a file.

SeasonApp's existing completed-result gate and recorded/saved flags protect unfinished games
and persistence retries. Shop mutations remain blocked during a live match. Postgame reads
the historical payout breakdown, not the current loadout, so later resale cannot erase income
history or imply a refund. UI confirmation retains exact prices, lost effect and sale proceeds;
scrollable review and visible controls use the established small-window contract.

Only three passive income contracts are supported. The score-only opponent resolver cannot
supply their attribution and is not granted income or sponsor purchases. All source numeric
contracts remain Working; existing Proposal physics mappings remain explicitly unapproved.

## Proposed initial Gear mappings, 2026-09-28

Catalogue3 adds a separate frozen `PROPOSAL_ITEMS` dictionary, preserving catalogue1/2 hashes
for build3/4 replay. Build5 stores and validates `mapped_gear_from`, copies it through atomic
forks, and gates both initial quotes and rerolls on that visit. Schema9 migrates only after
full old-journal replay and season validation; prior schema1–8 paths remain supported.

Bands receives the actual effort argument at successful pitch launch. Workload composes once
with normal effort cost/overdrive and never changes the rated pitch. Shoe speed is applied once
when configuring the active fielder and when planning pitcher pursuit. Both real control entry
points pass the owning defender's handling factor to the existing resolver. After original
reach/height rejection, difficulty changes by `max(0, difficulty) * (scale - 1)`; neutral
defaults remain exact, and negative reaction credit stays intact.

A runtime swing copy carries `gear_line_drive_strength` only for A02 Contact; Power receives
the fair exit multiplier instead. ContactResolver transforms the eligible angle before
constructing velocity, preserving magnitude, spray, spin and quality. Continuous proposed
shoulders retain the documented18–40°/0.65 eligibility. Current authored7° Contact geometry
only reaches18.2° at qualifying quality: this is an explicit calibration limitation, not a
reason to silently alter other chats' swing/gameplay fixes. UI calls out the negligible benefit.

The UI shows per-item Working/Proposal status in offers, equipped receipts and confirmation;
Cancel remains the default focus and all purchases still checkpoint before match handoff.
Confirmation review now uses a bounded, keyboard-focusable scroll container and fixed visible
44px confirmation controls. Long effect/replacement text cannot force the modal taller than
the700×400 minimum shop; the full cash/effect text remains accessible by scrolling.
These mappings remain unapproved Proposals; source numerical prices/effects remain Working.
No earned tier, permanent unlock or sponsor stack is implicitly introduced.

## Misc temporal/participation/reaction integration, 2026-09-28

`SeasonGearCatalog` keeps the original six-item dictionary intact for catalogue1/build3
fingerprints and adds a separate three-item Misc dictionary for catalogue2/build4. Schema8
replays all prior versions before adding `misc_from` at the next visit; generation before
that boundary uses catalogue1 exactly. The trusted bank supports all known contracts, but
player commands cannot create stock or prices. Existing atomic buy/replace/sell paths remain
shared. UI lookup resolves both catalogue generations and the route is now labelled Season Shop.

`PlayerMatchState.first_batter_completed` is independent of equipment. `MatchState` collects
unique pitcher-state references only when the live launch path reports a successful release.
Every completed PA marks those participants and clears the set before advancing the batter,
including walk-off/end-game completion. The workload selector reads this state before the
actual stamina debit. Windups, canceled attempts and menu equips do not grant participation
or refunds. Normal pause/resume retains the match object; a new match constructs fresh state.

`SwingProfileDefinition.contact_start/end` provides a separate temporal gate, with exact neutral
returns for legacy profiles. Gloves scale the two half-widths around the original sweet spot;
the original fields still drive barrel motion and animation. Both swept-segment overlap and
tracker expiry use the effective gate. Contact quality/error and spatial dimensions are not
rewritten. The existing fair-only exit modifier composes with the Bat penalty/benefit once.

Fielder configuration applies Goggles after deriving the baseline reaction from Fielding.
Pitcher pursuit uses the same helper on its existing0.20s gate. The positive1ms engineering
floor has no effect at current normal ratings. Immediate reach/handling checks, speed, obstacle
avoidance and current-ball planning remain unchanged. Sponsor reaction stacks are not implemented.

`season-misc` verifies temporal boundaries, first-PA ownership-independent participation,
reaction behavior, real UI input and old paid-state migration. `season-misc-live` reuses the
full-match harness with Kit and Gloves teams, keeping all four earlier complete-game fixtures.
Remaining Bands/Shoes mappings are documented instead of inventing new effort/error semantics.

## Gear purchase and resolver integration, 2026-09-28

`SeasonGearCatalog` isolates six supported Equipment v18 Working contracts, trusted ownership
prices/sale rules, eligible mixed stock and detached runtime adapters. `SeasonBuild` version3
adds `equip` and `sell_gear` commands. Both operate through a forked ownership bank and the
existing candidate/save boundary; failed quotes, explicit-replacement mismatches, insufficient
cash and write failures cannot leave partially sold Gear or consumed stock. Only current owned
roster definitions receive the bank's equipped identities; opponent/former definitions do not.

Schema7 is paired with build3. Build1/2 signatures and original generation remain available
for strict replay. Migration preserves all existing journal effects and records `gear_from`
at the following visit; a second save/load uses the same boundary. Recruitment activation
retains its independent earlier boundary. The bank's expanded trusted catalogue is not loaded
as client prices. Future enabled Gear/content-generation changes need explicit versioning;
do not alter the build3 fingerprint and silently invalidate paid saves.

Swing adapters clone both profiles, scale only X/Y radii and carry a neutral-default fair-exit
field into `ContactResolver`. The rated-pitch adapter follows mastery/effort and scales nominal
speed and existing movement force, with separate command-error scale propagated through launch
copies. Execution applies that scale only to existing release/direction dispersion. Rosin's
workload multiplier is applied at the successful real-release debit, so canceled/failed windups
do not consume stamina. Shared actor/solver paths serve both teams without modifying authored
resources or displayed ratings. Ball setup used by batted-ball physics is never replaced.

`SeasonGearShopUI` renders equipped receipts, legal offer previews and sales within the existing
scrolling/focus-safe shop. `season-gear` checks viewport clicks, normal/minimum bounds, cancel,
write failure, replacement, reload, migration and actual next-match actors. The full live-match
gate retains three prior games and adds a fourth equipped game. Native screenshots remain a
separate required human-review gate; no headless capture is presented as visual approval.

## Recruitment and roster-history replay, 2026-09-28

`RecruitCatalog` encodes all48 named tracks/prices and generates three authored stage profiles
from each original baseline. Alex's Eephus/OF exception is explicit. The physical adapter can
render a detached quoted profile without mutating ownership or authored player resources.

`SeasonBuild` version2 binds the initial roster, eligible pool and excluded opponent identities.
It uses a separate deterministic recruitment stream, records exact quote snapshots, preserves
appearance history and tracks an immutable first-contract fee for each acquired instance. The
`sign` command requires an exact live offer and outgoing member, debits the authoritative fee,
applies fresh catch-up only once and replaces membership atomically. Released profiles remain
in the development journal but cannot receive owned-player actions. They are not reserve items.

Schema6 loads/replays the build before validating retained results. Each reward records that
game's roster, allowing performance validation against historical membership instead of the
final lineup. Final saved batting order must match current build membership. The app preserves
batting and defensive positions while substituting the explicitly released player; failed saves
restore both the previous build and actual lineup. Former-player totals use derived game rosters.

Version1 build/schema5 migration retains all old commands and current stock. Its recruitment
activation starts at the next postgame visit, so it cannot generate a bonus quote or reroll a
paid pack during load. Schema1–4 behavior is preserved. Quote validation normalizes both sides
through JSON before deep comparison because Godot parses integer JSON values as floats; every
field/value still must match replay. Invalid edited quotes, pools and historical rosters fail closed.

Only the normal four-player season is wired here. No extra reserve limit, persistent player-card
grant, learned-ability carry, intra-Doubleheader workload or paid AI recruiting is implied. Those
need their own complete state contracts. Gear/sponsor effect integration remains the next slice.

## Atomic paid-season aggregate, 2026-09-28

`SeasonBuild` owns the Working-season wallet, held receipts, development journal and visit
stock. A candidate forks all components, revalidates the exact target and authoritative price,
then publishes all changes together. UI commands cannot supply arbitrary credits/debits.
Revision/request identities reject stale choices and make repeated confirmations replay safely.

`SeasonApp.commit_shop` validates a candidate, saves the aggregate, and restores the previous
in-memory aggregate if persistence fails. Schema5 stores the seed, roster, catalogue fingerprint
and replayable commands, not separately editable balances or ratings. Loading also matches every
reward to retained fixture outcomes and rejects shopping after completion. Schema4/default and
legacy1–3 behavior is preserved. Draft saves use an explicitly typed empty aggregate roster.

`DevelopmentShopCatalog` supplies Working card/lesson definitions and exact legal targets.
Fixed pack identities are generated once per visit; ordinary rerolls use independent seeded
streams and cannot refresh that pack. Pack opening rechecks eligibility before charging, and
pending paid choices persist across reload. No held-capacity or affordability filter removes
otherwise eligible stock. Unsupported categories are absent rather than represented by grants.

The Working season uses `ProgressionMatchAdapter` for actual rosters and paid next-match state.
The default season remains on the original resources. Offscreen opponent strengths currently
use their drafted baseline; paid AI growth and AI recruiting are later integrations. The new shop
has scrollable targets, fixed navigation, wrapped actions and a bounded confirmation dialog.
Headless UI input/layout checks and optional native screenshot checks are separate evidence.

## Reconstructed progression playtest boundary, 2026-09-28

`SeasonDevelopment` stores a replayable journal keyed to one season instance and the
exact Working catalog fingerprint. Four broad stats and active/remembered exact-recipe
mastery are detached query snapshots, not editable authoritative save blobs. New recipes
start1, remembered levels restore, and active capacity replacements are explicit. Unsupported
Exotics and retired stat grants fail before publishing a candidate. Acquisition/payment is
integrated by `SeasonBuild` above; this development ledger alone grants no purchase.

`ProgressionMatchAdapter` duplicates player/recipe resources for exhibitions and Working seasons.
Four-stat ratings feed the existing contact, fielding, release and stamina consumers.
The internal Control/Stamina fields both receive Pitching. Velocity/Break factors are
bypassed only for explicitly marked test instances; ordinary resources remain neutral.
`command_only_quality` separates command from quality-driven velocity/spin scaling in this
path. Ordinary fatigue and effort still apply for both human and AI pitchers.

New **unapproved calibration Proposals**, isolated to `PitchMastery` test recipes:

| Ladder | Candidate physical mapping |
| --- | --- |
| Four-Seam / Riser levels2,4 | +0.06 per step to an aerodynamic movement scale, after the existing lift coefficient clamp |
| Four-Seam / Riser levels3,5 | +0.025 per step times authored recipe velocity; cumulative, never compounded on an already mastered copy |
| Slider / Sinker / Drop levels2,4 | +0.18 per step to a continuous early-to-late force bias; no discontinuous path turn |
| Slider / Sinker / Drop levels3,5 | +0.08 per step to aerodynamic movement scale |
| Eephus / Knuckleball each level | Execution velocity spread, release/direction sigma and orientation error ×0.92; nominal speed and natural seeded wobble remain |

Late bias uses normalized current Z progress from release to plate: weight
`1 + bias * (2 * progress - 1)`. It redistributes aerodynamic forces while retaining the
recipe's axis/sign. It does not inspect target error or a future path. The 240Hz shared
solver and aim simulator apply the same envelope, including the integration midpoint.
New launch parameters survive copies into execution and the live actor. Neutral defaults
leave ordinary match parameters unchanged. The existing aim compensation is retained.

Home > Player Growth Test Lab exposes four ratings, exact pitch levels, next-effect
previews, explicit lesson replacement, inactive remembered mastery, isolated save/reload
and a managed test exhibition. A successful test save is required before launch. Match
inspection and pitch controls show the test's four ratings/levels. Paid development now has
an opt-in seasonal path; gear stacks, abilities and balance remain pending.

Build the core sport so that:

- pitching is highly tunable and distinctive
- batting is skill-driven and readable
- physical fields matter
- baseball rules remain deterministic and testable
- mobile is a first-class architectural target
- later roguelike systems can modify the sport without rewriting it

Governing architecture rule:

**Godot owns presentation, collision, and environment physics. Our code owns baseball.**

---

# 2. Engine Baseline

- Godot 4.7.2
- typed GDScript
- Mobile renderer
- Jolt 3D physics
- Godot physics tick: 60 Hz initially
- custom Pitch integration: 240 Hz internal substeps initially
- physics interpolation enabled
- Blender → glTF/GLB
- Git/GitHub
- SI units internally: meters, seconds, kilograms

Do not upgrade the engine mid-production casually.

Patch upgrades may be evaluated deliberately. Major/minor engine upgrades require a concrete benefit and regression check.

---

# 3. Architectural Layers

Use three explicit conceptual layers:

## Definition

Authored, reusable content.

Examples:

- PlayerDefinition
- PitchDefinition
- DeliveryProfileDefinition
- BallAeroProfileDefinition
- BallSetupDefinition
- SwingProfileDefinition
- FieldDefinition
- FieldFeatureDefinition

Use Godot `Resource`.

Definitions are treated as immutable at runtime.

## Simulation / State

Mutable game state and pure-ish logic.

Examples:

- PlayerSeasonState
- PlayerMatchState
- PitcherState
- PitchState
- PitchLaunchParameters
- SwingIntent
- ContactResult
- BattedBallLaunch
- BaseState
- BallPlayState
- BallPlayOutcome
- MatchState

Prefer `RefCounted` for state classes that do not need scene-tree behavior.

## Presentation / Engine Actors

Things that need Nodes, transforms, collision, animation, rendering, or UI.

Examples:

- PitchFlightActor
- BattedBallBody
- BatterActor
- BatActor
- PitcherActor
- FielderController
- MatchController
- UI

Do not collapse all three layers into one Node script.

---

# 4. Content Definitions

Initial minimum definition hierarchy:

```text
DefinitionBase
├── PlayerDefinition
├── PitchDefinition
├── DeliveryProfileDefinition
├── BallAeroProfileDefinition
├── BallSetupDefinition
├── SwingProfileDefinition
├── FieldDefinition
├── FieldFeatureDefinition
└── StrikeZoneDefinition
```

Later:

```text
PlayerAbilityDefinition
GearDefinition
EndorsementDefinition
LeagueDefinition
DifficultyDefinition
StadiumPartDefinition
```

## Stable IDs

Every definition has a stable content ID.

Examples:

```text
pitch.overhand_four_seam
pitch.sidearm_sinker
player.sal
field.backyard_01
```

Save data must reference stable IDs, not resource paths.

---

# 5. Content Manifest

Create one explicit `ContentManifest.tres`.

It references all authored content.

`ContentDB` loads the manifest and builds lookup dictionaries such as:

```text
pitch_by_id
player_by_id
field_by_id
ball_setup_by_id
```

Do not rely on arbitrary runtime directory scanning as the primary content-registration system.

---

# 6. Autoload Policy

Initial Autoloads:

```text
ContentDB
```

Add `SaveService` only when persistent saves begin.

Avoid giant global managers.

Do not begin with:

```text
GameManager
BaseballManager
PhysicsManager
GlobalEventBus
```

Match-local systems remain match-local.

---

# 7. Match-Local Architecture

A match owns:

```text
MatchController
MatchEventHub
MatchState
BallPlayResolver
FieldingResolver
TagAdvanceResolver
```

When the match ends, its event system and transient simulation state die with it.

Later modifiers may subscribe to match-local events without turning the entire game into a global singleton architecture.

---

# 8. Repository Layout

Recommended starting structure:

```text
/project.godot

/docs/
    .gdignore
    SOURCE_OF_TRUTH.md
    TECHNICAL_PREPRODUCTION.md

/src/
    core/
        ids/
        math/
        rng/

    content/
        definitions/
        manifest/

    gameplay/
        pitching/
        batting/
        ball_in_play/
        fielding/
        match/

    presentation/
        characters/
        ball/
        camera/
        ui/

    labs/
        pitch_bat_lab/
        ball_in_play_lab/

    tools/
        debug/

    tests/
        unit/
        integration/

/assets/
    environment/
    characters/
    audio/

/art_source/
    .gdignore
```

Keep working Blender source in `art_source/`.

Export clean GLB/glTF assets into `/assets/`.

---

# 9. Coordinate and Unit Conventions

Use SI units internally.

World convention should be documented immediately and never casually changed.

Recommended field-local convention:

```text
+Y = up
+Z = from home plate toward center field
+X = toward right field
```

For Pitch authoring, also define a semantic pitcher-relative frame:

```text
arm_side
up
toward_plate
```

Handedness maps the semantic frame to world space.

Spin is an axial vector. Across a world-X reflection, ordinary positions and
directions map to `(-x, y, z)`, but spin maps to `(x, -y, -z)`. Applying the
ordinary vector mapping to angular velocity inverted left-handed vertical break.
`pitcher_spin_vector` preserves right-handed authored mapping and applies the
axial reflection for lefties. Hole axes reflect as ordinary directions; seeded
angular wobble/orientation errors use axial reflection. Release-position and
yaw errors mirror laterally. `PitchLaunchParameters.is_left_handed` survives
copies so the execution model and solver share that convention. No aerodynamic
coefficient, rating multiplier or fatigue curve changes with this correction.

Do not author Pitch movement using hardcoded world-left/world-right when “arm side” or “glove side” is the real meaning.

---

# 10. Pitch Definition

A game-facing **Pitch** includes pitch type + delivery/arm slot.

A `PitchDefinition` should carry authored tactical/physical identity such as:

```text
id
display_name
category
delivery_profile
nominal_velocity
nominal_spin_rate
nominal_spin_axis
hole_orientation
control_difficulty
execution_difficulty
stamina_cost
recognition_difficulty
timing_difficulty
mistake_punish
rarity
tags
aero_recipe/profile references
```

Exact final schema should remain lean until the first solver is running.

Do not duplicate data merely because it may become useful later.

---

# 11. Ball Setup vs Pitch

Keep Pitch identity and ball condition separate.

## PitchDefinition

Describes release recipe / intended pitch identity.

## BallSetupDefinition

Describes the aerodynamic object/condition.

Possible ball parameters:

- drag multiplier
- perforation-force multiplier
- stability
- surface asymmetry
- scuff profile

This allows the same Pitch to behave differently with different ball setups without duplicating the Pitch definition.

---

# 12. Pitch Runtime State

Conceptual baseline:

```gdscript
class_name PitchState
extends RefCounted

var position: Vector3
var velocity: Vector3

var orientation: Quaternion
var angular_velocity: Vector3

var elapsed_time: float
var pitch_id: StringName
var seed: int
```

The solver should operate on explicit state rather than reading arbitrary Nodes or player objects.

---

# 13. Pitch Launch Builder

Separate gameplay stats from physical simulation.

`PitchLaunchBuilder` combines:

- PitchDefinition
- DeliveryProfile
- PlayerMatchState
- BallSetupDefinition
- player handedness
- Natural Delivery compatibility
- aim
- effort
- execution input
- Stamina/fatigue
- applicable modifiers

and produces:

```text
PitchLaunchParameters
```

The aerodynamic solver receives physical launch parameters.

It should not know whether the Pitch came from Sal, an Endorsement, or an Exhausted state.

Prototype effort is a bounded per-pitch input. It scales launch velocity and
modestly changes movement authority before nominal aim solving. Higher effort
also raises Stamina cost and introduces a small execution penalty. The initial
lab range is 82–112%; exact limits and curves remain tuning values.

Prototype player release uses a fast meter with a late command sweet spot near
85% progress. The small post-sweet-spot tail reports a normalized release
overdrive value. `MatchLabSupport` applies bounded category-aware stuff (more
velocity for Fastballs; more spin/perforation authority for breaking Pitches)
before nominal aim solving, then applies an explicit execution-quality and
Stamina penalty. This preserves one aim/flight pipeline and prevents the meter
from becoming a second unbounded effort control.

---

# 14. Pitch Simulation Ownership

Do **not** use `RigidBody3D` as the authoritative Pitch-flight model.

During pitch flight:

```text
PitchFlightActor : Node3D
```

owns a `PitchState`.

The authoritative Pitch ends at the mathematical plate-crossing event. Its
presentation may continue a short, non-interactive catch-through beyond the
plate before hiding. That visual tail cannot accept contact, change the call,
or remain visible into the next Pitch.

The custom solver advances the Pitch.

Godot/Jolt provides world collision queries.

This preserves precise authorship over:

- velocity
- drag
- lift
- spin
- effective spin
- hole orientation
- unstable movement
- exaggerated plastic-ball behavior
- fictional future Pitches

without fighting rigid-body integration.

---

# 15. Pitch Timestep

Initial baseline:

```text
Godot physics: 60 Hz
Pitch solver: 240 Hz
Pitch substep: 1 / 240 s
```

Each 60 Hz physics tick performs four Pitch substeps.

Reason:

A fast pitch travels too far per 60 Hz tick for comfortable trajectory integration, while making the entire game run at 240 Hz is unnecessary.

Collision detection still sweeps the whole movement segment.

## Convergence test

Before treating 240 Hz as permanent, compare:

- 120 Hz
- 240 Hz
- 480 Hz

For extreme prototype Pitches.

If 240 → 480 produces materially visible plate-position differences, either improve the integrator or increase the Pitch step rate.

---

# 16. Pitch Integrator

Use a fixed-step midpoint / RK2 integrator initially.

Per substep:

1. evaluate acceleration at current state
2. estimate midpoint state
3. evaluate acceleration at midpoint
4. advance position/velocity
5. advance orientation
6. sweep ball shape from previous → next position
7. process any collision/event

Avoid:

- render-delta-driven Euler
- unnecessary RK4 complexity before evidence requires it

---

# 17. Pitch Forces

Initial force families:

## Gravity

Standard downward acceleration.

## Drag

Quadratic drag based on relative airflow.

Conceptually:

```text
F_drag ∝ -|v_rel| * v_rel
```

## Spin / Magnus-type force

Use active/effective spin and spin axis to derive transverse lift.

Do not use:

```text
more spin = more Break
```

as a simplistic rule.

## Plastic-ball perforation / asymmetry force

Model orientation-dependent aerodynamic bias separately from conventional spin lift.

This is required because perforated plastic balls can generate strong orientation-dependent movement and can curve even with low spin.

Total Pitch acceleration is therefore conceptually:

```text
gravity
+ drag
+ spin-induced lift
+ perforation/asymmetry force
+ optional wind
```

---

# 18. Ball Orientation

Maintain ball orientation explicitly.

Conceptually:

```text
orientation: Quaternion
angular_velocity: Vector3
```

The aerodynamic profile knows the perforated-hemisphere/hole axis in local ball space.

Each solver step transforms that axis to world space and evaluates its relationship to airflow.

This enables physically grounded orientation-dependent plastic-ball movement.

---

# 19. Knuckleball Model

Do not implement arbitrary random lateral impulses.

Prototype model:

- low spin
- low orientation stability
- small seeded deterministic wobble torque
- orientation changes
- changing orientation changes asymmetric aerodynamic force
- resulting path becomes irregular

Seed the behavior so identical launch conditions are reproducible for debugging.

---

# 20. Eephus Model

No special fake trajectory system.

Use:

- very low launch speed
- high arc
- normal gravity
- low conventional break
- low Stamina cost as gameplay data

The same solver handles it.

---

# 21. Pitch Aim Semantics

The player's aim cursor represents the **intended plate-crossing location**.

It does not directly represent initial launch direction.

Use:

```text
PitchAimSolver
```

to solve for the nominal initial launch direction that makes a perfectly executed Pitch reach the desired target.

Conceptually:

1. choose target point
2. guess launch direction
3. simulate nominal Pitch
4. measure crossing error
5. adjust direction
6. repeat a small number of iterations

Because this is one ball and a tiny search problem, runtime cost is negligible.

Very slow/high-arc Pitches should seed the search with a gravity-compensated
guide height and retain enough bounded iterations to find a crossing across the
authored aim area. A failed solve must restore `PRE_PITCH` without spending
Stamina, incrementing pitch count, or leaving the match soft-locked. An AI
Pitcher failure schedules a known-good repertoire/center fallback through the
normal visible delivery cadence; a player Pitcher remains in the ready state.

An accepted solve must meet the existing 1.25 cm target tolerance. Merely
crossing the plate is not success: the old best-candidate fallback could send
an underpowered Eephus far below a high aim point. If no candidate converges,
return failure and retain the safe retry behavior above. Do not silently add
velocity to satisfy the target. Minimum-effort Eephus reach depends on the
Pitcher's velocity and the requested height; the tested 90% effort fixture
can reach low, center, and high targets for both hands.

---

# 22. Execution Error and Hangers

Apply execution/fatigue error **after** nominal target solving.

Velocity degradation must not create a dominant artificial dirt bias. The
execution layer may apply a bounded vertical release-angle compensation for
the extra gravity drop caused by lost velocity. This compensation preserves
the intended vertical reach only; it does not correct lateral movement,
attenuated break, release error, or later command error.

Possible degraded launch properties:

- spin magnitude
- spin axis
- hole orientation
- release position
- launch direction
- velocity

Fatigue uses a back-loaded severity curve rather than raw linear Stamina loss.
The initial match bands are:

- 0–35% fatigue: no mechanical penalty
- 35–50%: trace variance, reaching only 2.5% effect at 50%
- 50–83%: gentle nonlinear degradation, reaching 25% pressure at 17% Stamina
- 83–100%: pressure rises from 25% to 100%; crisis/lapse rolls begin here

Match capacity is `(105 + 18 * Stamina rating) * 1.08`. These are distinct
quantities: the HUD shows Stamina remaining, while diagnostic fatigue is spent
capacity. Twenty percent remaining means 80% fatigue, not 20% fatigue.

Velocity, movement authority, release position, and launch direction receive
separate seeded rolls. Faster Pitches have more velocity to lose; breaking
Pitches lose a larger share of spin/finish. Heavy-tail lapses are reserved for
the upper fatigue band instead of appearing throughout an ordinary outing.

A fatigued Slider aimed outside may fail to achieve expected movement and
remain over the plate. At high fatigue, a continuous seeded command-regression
term also pulls misses toward the heart, weighted most strongly for edge and
corner targets. This supplements degraded stuff and variable execution; it
does not replace every target with the zone center.

That naturally creates a hanger.

Re-aim weakened velocity/spin/perforation/instability together before adding
release/direction/orientation errors. The previous vertical compensation ran
before movement loss, causing breaking pitches to miss by large distances at
ordinary targets. Command errors and seeded center pull remain separate, so this
does not restore lost movement or guarantee a Strike. The final reach floor is
0.12 m at the plate, keeping the ball visible above the ground.

A final reach guard prevents velocity loss and error from sending exhausted
Pitches below the simulation world before the plate plane. It does not force a
strike: low, high, and lateral misses remain valid. At 100% fatigue, Pitches
should still arrive but resemble batting practice through lost speed, flattened
shape, and frequent hittable location.

Avoid special-case code like:

```text
if stamina == 0:
    pitch_to_center()
```

---

# 23. Pitch Collision

During custom Pitch flight, use sphere/shape sweep queries along:

```text
previous_position -> next_position
```

for relevant solid interactions.

Do not rely on discrete point overlap.

The Pitch is not a Jolt rigid body during this phase.

---

# 24. Strike-Zone Crossing

Represent the plate/strike-zone plane mathematically.

Determine:

- crossing position
- Ball/Strike
- pitch location
- any relevant visual crossing data

from the sampled/swept trajectory.

Keep strike logic separate from presentation.

---

# 25. Batting Authority

The rendered bat is **not** authoritative for gameplay contact.

Use a mathematical arcade contact model.

The bat animation exists for presentation and synchronization. Its handed
stance, swing direction, and visible swing-plane tilt should read from the same
`SwingProfileDefinition` handedness and attack angle used by the resolver, but
the mesh remains non-authoritative. Its square-across-plate pose must occur at
the profile's `sweet_spot_time`, not at the animation's arbitrary midpoint or
finish. The ready stance is the loaded pose; after commitment, the barrel
drives directly through that synchronized contact pose and then decelerates
into a short front-shoulder finish. Do not use a full-circle recovery. The
separate Batter presentation should animate its hands and body on the same
timeline without merging character and equipment ownership.

Do not determine whether a swing succeeds based on tiny collider overlap at engine physics frequency.

---

# 26. Batting Coordinate Frame

Define a plate-local contact frame.

Recommended semantic axes:

- horizontal across zone
- vertical
- depth toward/away from Pitcher

The player's aim sets a target contact region in the plate plane.

---

# 27. Swing Profiles

Initial authored profiles:

```text
ContactSwingProfile
PowerSwingProfile
```

Potential fields:

```text
contact_radius_x
contact_radius_y
contact_depth
swing_duration
contact_window_start
contact_window_end
sweet_spot_time
bat_speed
attack_angle
exit_velocity_multiplier
```

## Contact

- larger valid contact volume
- longer timing forgiveness
- lower EV ceiling

## Power

- smaller valid volume
- tighter timing
- higher EV ceiling

Keep these values in data, not hardcoded into Batter logic.

---

# 28. Swing Intent

On swing input, record:

```text
swing_type
start_time
aim_point
handedness
```

plus any minimal modifier state required.

This becomes `SwingIntent`.

For mouse input, project the pointer ray onto the authored contact plane. The
projected plate-local X/Y becomes `aim_point`, and the mouse button chooses the
Swing Profile. This preserves the same mathematical ContactResolver authority
used by keyboard/controller aim; mouse picking never substitutes a physics
collider for contact resolution.

`BatterApproachModel` owns deterministic opponent recognition and decision
quality. Its memory resets per plate appearance and may learn from previously
observed Pitch identities and visible late-flight location buckets. It must not
read the player's intended target. Pitch-authored recognition, timing, and
mistake-punish values preserve differences such as a deceptive first Eephus
versus a repeated center-hanging Eephus.

The visual Batter and bat mirror handedness and animate the committed Swing,
but `ContactResolver` remains authoritative. Presentation geometry never adds
a second collision-based batting result.

---

# 29. Contact Resolver

During the valid contact interval, compare each authoritative 240 Hz Pitch
segment against the moving virtual contact region. Resolve the closest valid
encounter within that segment rather than evaluating the ball only at the input
frame. A committed swing may therefore begin before the Pitch reaches the
contact plane.

The virtual region's center travels in depth and height on the authored attack
plane, crossing the player's aimed X/Y point at `sweet_spot_time`. This makes
Pitch-descent/attack-angle alignment part of timing forgiveness and makes the
vertical ball/barrel offset at the actual encounter authoritative for launch
and spin. It does not move the player's aim point or create contact after the
authored window closes.

Evaluate:

- spatial error
- timing error
- swing phase
- bat/ball vertical relationship

Select the best valid encounter.

Outcomes can include:

- miss
- foul/weak contact
- solid contact
- near-perfect/perfect contact

Exact thresholds remain tuning data.

The independent `BatActor` uses the same profile sweet-spot time but remains
presentation-only. Its authored pose path is load → slot/drive → square contact
→ extension → decelerating front-shoulder finish. `PlayerAvatar` mirrors the
same handed path and adds bounded torso/weight transfer while counter-transforming
the hands so they remain attached to the bat. Aim posture is strongest at rest,
still partially expressed at contact, and fades during the finish. No mesh
collision may replace `ContactResolver` as baseball authority.

If the moving Pitch never encounters the virtual region before the authored
window closes, record an early/late or spatial miss but do not stop Pitch
flight. The authoritative Pitch continues to its plate-crossing call and its
non-interactive receiver presentation. Fair contact and fouls end custom Pitch
flight at the resolved encounter. Both then transition to a physical Jolt ball:
fair contact enters normal BallPlayResolver rules, while a foul remains live
only for a clean airborne catch and otherwise resolves on first ground or
out-of-play contact.

### Research basis

The arcade resolver should preserve the useful relationships from Alan
Nathan's ball-bat collision work without attempting a deformable-body bat
simulation: incoming Pitch velocity/spin, bat velocity/direction, attack angle,
ball-bat centerline offset, and actual encounter timing jointly determine exit
speed, launch angle, spray, and spin. In particular, centerline offset remains
the primary launch-angle control, while useful attack-angle alignment preserves
exit speed. See [Optimizing the Swing](https://baseball.physics.illinois.edu/OptimizingTheSwing.pdf),
[Optimizing the Swing II](https://baseball.physics.illinois.edu/OptimizingTheSwingII.pdf),
and [Modeling the Ball-Bat Collision](https://baseball.physics.illinois.edu/AJP-Oct2006.pdf).
The presentation timing also follows the measured kinetic sequence summarized
in [Welch et al. (1995)](https://pubmed.ncbi.nlm.nih.gov/8580946/): hips,
shoulders, arms, and bat accelerate sequentially, with bat speed peaking just
before impact. Current Statcast definitions provide useful validation ranges
for [attack angle](https://www.mlb.com/glossary/statcast/attack-angle),
[swing-path tilt](https://www.mlb.com/glossary/statcast/swing-path-tilt), and
[swing length](https://www.mlb.com/glossary/statcast/swing-length); these are
references for readable relationships, not a mandate to copy MLB scale into
the plastic-ball game.

---

# 30. Spray Direction

Derive spray from actual swing/contact timing rather than a separate magic directional rule.

Early contact occurs farther in front:

- more pull

Centered timing:

- more center

Late contact occurs deeper:

- more opposite field

Handedness mirrors direction appropriately.

---

# 31. Launch Angle

Derive launch tendency from bat/ball vertical relationship and swing attack angle.

Simplified concept:

- contact below ball center → more lift/backspin
- contact near center → line-drive tendency
- contact above ball center → ground-ball/topspin tendency

Preserve the sign of this spin tendency when launching the physical ball.
Clamping negative offset to zero spin erases a useful, readable distinction
between undercut fly contact and rollover ground contact.

The launch bridge also carries the Pitch ball's orientation and derives bounded
side/gyro components from spray and horizontal contact error. This gives Jolt
flight deterministic carry, fade, drop, and roller variety without choosing a
hit result through hidden randomness.

This produces understandable arcade outcomes while retaining a physical basis.

---

# 32. Exit Velocity

Use a tunable physically inspired transfer model rather than full material-deformation simulation.

Conceptually:

```text
base transfer from incoming pitch speed
+ effective bat speed
```

then modify by:

- contact quality
- sweet-spot quality
- Power stat
- swing profile
- Gear/modifiers

Design distinction:

- Power increases ceiling/effective bat speed
- Contact preserves quality under imperfect timing/position

---

# 33. Batted-Ball Spin

`ContactResolver` also produces initial batted-ball angular velocity.

Inputs may include:

- vertical offset
- horizontal offset
- attack angle
- timing
- smaller inherited component from Pitch spin

Output:

```gdscript
class_name BattedBallLaunch
extends RefCounted

var position: Vector3
var velocity: Vector3
var angular_velocity: Vector3
var orientation: Quaternion
var contact_quality: float
```

This object marks the transition from Pitch flight to ball-in-play.

---

# 34. Ball-in-Play Ownership

Architecture boundary:

```text
CUSTOM PITCH SOLVER
        ↓
CONTACT RESOLVER
        ↓
BATTED BALL LAUNCH
        ↓
JOLT RIGID BODY
```

After contact, emergent physical collision becomes desirable.

---

# 35. BattedBallBody

Use:

```text
BattedBallBody : RigidBody3D
```

with:

- CCD enabled
- contact monitoring enabled as needed
- custom aerodynamic force application
- simplified gameplay collision proxies for very thin geometry when required

Godot/Jolt handles:

- ground impact
- wall/fence bounce
- poles
- roofs
- trees
- ramps
- later physical objects

Our code still owns baseball rulings.

---

# 36. Batted-Ball Aerodynamics

Continue applying authored ball forces during ball-in-play:

- gravity
- drag
- spin lift
- plastic-ball asymmetry
- wind if present

Jolt handles collision response.

Do not surrender ball flight identity entirely after contact.

---

# 37. Baseball Rules vs Physics

Critical rule:

**A collision does not itself decide the baseball result.**

Physics emits physical events.

`BallPlayResolver` interprets those events according to the current FieldDefinition and baseball rules.

Example:

Hitting a wall is not universally a Double.

The resolver checks:

- whether the ball grounded first
- which wall/region was hit
- current field ground rules
- whether a more final result already occurred

---

# 38. FieldDefinition

Gameplay geometry is authored in field-local coordinates.

Home plate is the logical origin.

The definition may include:

- fair territory
- foul boundaries
- ordinary safe-hit boundary
- deep-air Double regions
- back wall/fence
- HR boundary
- fielder anchors
- ground-rule regions
- relevant return/throw destinations

The visual/collision mesh and scoring geometry are related but not identical.

This allows gameplay boundaries to be tuned without remodeling Blender geometry.

---

# 39. Important Rule Boundaries

For critical non-solid rule boundaries, mathematically test the ball segment:

```text
previous_position -> current_position
```

against the boundary.

Do not rely exclusively on thin `Area3D` triggers for:

- HR plane
- safe-hit boundary
- foul-line/rule crossing
Use physical collisions for solid objects.

Use mathematical crossing tests for rule geometry.

---

# 40. BallPlayState

Track the minimum state needed to resolve the play, such as:

```text
is_fair
is_foul_play
has_grounded
first_ground_position
result_floor
last_defender_touch
caught
dead
catch_position
catch_time
```

`result_floor` conceptually supports:

```text
NONE
SINGLE
DOUBLE
TRIPLE
HOME_RUN
```

Do not overgrow this object until the actual prototype requires more.

---

# 41. Baseline Hit-Result Flow

Examples:

## Ground ball beats defense

- result floor = NONE
- crosses ordinary safe boundary
- floor becomes SINGLE
- fielder later controls it
- final result = SINGLE

## Fly ball hits wall on the fly

- has_grounded = false
- wall-on-fly rule triggers
- result = TRIPLE

## Bouncing ball reaches wall

- has_grounded = true
- reaches back wall
- result = DOUBLE

## Clears HR boundary on fly

- result = HOME_RUN
- play becomes dead

## Live foul

- `is_foul_play = true`
- safe/deep/HR advancement boundaries are ignored
- a clean airborne defensive control resolves an Out
- first ground or out-of-play contact resolves a Foul and applies the count rule

## Moving grounder before the Single line

- ball has grounded but remains above the authored settled-speed threshold
- clean Primary Fielder control before the safe boundary resolves an Out
- a stopped ball or any ball that already crossed the safe boundary retains at
  least a Single from the Primary Fielder
- a clean moving-ground-ball control inside the Pitcher's fixed mound envelope
  remains an Out exception even after the ball crosses the Single line

---

# 42. Primary Fielder

Presentation actor:

```text
FielderController : CharacterBody3D
```

Gameplay authority comes from a separate planner/resolver.

The physical fielder collider does not automatically determine catch success.

---

# 43. Fielder Planner

`FielderPlanner` predicts useful intercept opportunities from:

- current ball position
- velocity
- spin
- expected flight
- current fielder anchor/start position
- fielder movement capability

The planner chooses a reachable intercept.

After unexpected bounces/collisions, re-plan.

Initial predictor only needs to be good enough for:

- flight until first ground
- simple bounce/roll approximation

Do not build a perfect general future-physics solver before the prototype needs it.

---

# 44. Fielder Positioning

`FieldDefinition` exposes a 3×3 tactical layout with seven legal starter-field
anchors:

- Shallow Left
- Shallow Right
- Middle Left
- Middle Right
- Deep Left
- Deep Center
- Deep Right

The user's pre-pitch strategic choice selects one anchor.

Authored anchors must respect both the Pitcher exclusion radius and the delivery
sightline. The starter field disables Shallow Center and Middle Center as
`PITCHER LANE`; Deep Center remains legal. Direct selection, cycling, defaults,
and AI placement must all honor the same availability rule. Shallow side
anchors may be in front of the mound in depth but must stay laterally clear of
Pitch trajectories and batting/pitching camera sightlines. The starter field
uses X +/-5.5 m and depth rows 8.5, 14.0, and 19.5 m. Tests sample the actual
Pitch solver across all nine Pitches, both throwing hands, corner targets, and
fresh/stressed execution. Passing that finite matrix is not proof of a global
maximum trajectory envelope; unusual flights still require runtime QC.

The Match UI may expose these anchors in an overhead Field Setup camera. The
view is pre-pitch only and must return to the normal Pitching shot before a
Pitch can begin. Its player-facing grid is displayed from deep to shallow, with
disabled Pitcher-lane cells retained so the spatial layout stays legible.
Left/right labels follow the view from home plate toward the field rather than
raw world-X naming. The starter Field Setup view is orthographic so authored
depth and scoring-plane spacing are not compressed by perspective.

After contact, the fielder moves according to the planner.

The opponent chooses a new anchor between batters from visible Batter
handedness and Power plus a deterministic seed. It cannot read future contact.
The Fielder remains inactive at its anchor until ball-in-play begins. After
contact it may cross in front of the mound. `DefenderSpacing` checks full
movement segments against a 1.55 m body-clearance disc at the actual Pitcher position and picks
a deterministic clear heading toward the intercept. The clearance includes
both avatars and the Pitcher's existing visual reaction step. It is not a
ball-control radius or a whole-field depth clamp. FieldingResolver still owns
ball control; movement has no ball collider. Physical bump/error responses
remain deferred.

---

# 45. Fielding Resolver

At the interaction moment, evaluate:

- distance/reach
- ball speed
- arrival timing
- bounce state
- reach difficulty
- Fielding stat
- Fielding Ability if relevant

Base result bands:

- clean
- bobble
- miss

Prefer readable deterministic thresholds over hidden RNG in the baseline.

The resolver must reject interactions outside explicit horizontal and vertical
reach limits before applying clean/bobble bands. The visible actor's actual
position—not only the planner's predicted intercept—supplies interaction
distance.

Randomness can be introduced later only when it improves the game.

---

# 46. Bobble / Deflection

A bobble should physically affect the ball.

`DeflectionModel` may alter:

- speed
- direction
- spin

based on the interaction.

Baseline rule:

A bobbled fair ball normally establishes at least a Single.

Recovery may still prevent further advancement.

---

# 47. Pitcher Defense

Use the same general fielding resolution model with a restricted Pitcher reaction envelope.

Pitcher may:

- catch comeback liners
- field weak grounders
- deflect hard contact
- turn a still-moving fair grounder into an Out inside the fixed mound envelope

`PitchBatLabDefenseSupport` permits bounded pursuit after contact:
0.20 s reaction delay, a moving ball, a reachable `FielderPlanner` intercept
within 5.0 m of the original mound, and Fielding-scaled speed of 3.6–4.6 m/s.
Grounders and nearby air balls qualify; the Pitcher is slower than the Primary
Fielder. Both defenders route around the other's actual body position.
The attempt radius remains 0.60 m around the visible Pitcher, without remote
control or pre-contact pursuit. The fielding pose persists through the result hold.

Scoring floors are observed through the swept control position before applying
the outcome. Outside the original fixed mound envelope, charging control follows
the ordinary Single rule. Only verified clean moving control inside the original
mound envelope can erase Single. Stopped balls, bobbles and Double-or-higher
floors remain safe; pursuit does not move that exceptional scoring region.

Test that small envelope against the swept batted-ball segment each physics
frame. This prevents high-speed tunneling without increasing the radius or
granting control outside the visible reaction space.

---

# 48. Defensive Assignment Logic

`PlayerMatchState.pitching_finished` is set when an arm with at least one thrown
Pitch is replaced. `TeamMatchState.select_pitcher()` rejects returning arms;
cycling skips them. Batting and fielding eligibility are unchanged. A pre-Pitch
lineup preview does not burn an unused arm. The AI checks only between Batters,
keeps the current arm above 17% Stamina, and otherwise selects the freshest
eligible replacement. It keeps the current arm if no fresher replacement exists.

Between batters:

- choose/change Pitcher
- choose/change Primary Fielder

The Pitcher cannot simultaneously be the Primary Fielder.

Before each pitch:

- optionally reposition Primary Fielder among the field's legal tactical cells

Selections persist until changed.

---

# 49. Ghost Base State

Keep base occupancy pure logic.

Conceptual:

```gdscript
class_name BaseState
extends RefCounted

var first: RunnerToken
var second: RunnerToken
var third: RunnerToken
```

`RunnerToken` initially needs only enough identity to connect the runner to the batting order/player state.

No 3D runner object is required.

---

# 50. Sac-Fly / Tag Resolver

After a fly catch:

`TagAdvanceResolver` considers:

- catch position
- defensive return destination
- estimated defensive return time
- fielder ability
- standardized runner advancement time
- safety margin

Conceptually:

```text
if runner_advance_time + safety_margin < defensive_return_time:
    runner advances
```

No Speed stat initially.

---

# 51. Match State Machine

Use explicit phases.

Conceptual baseline:

```text
BETWEEN_BATTERS
    ↓
PRE_PITCH
    ↓
PITCH_IN_FLIGHT
    ↓
    ├── no contact → PITCH_RESOLUTION
    │
    └── contact → BALL_IN_PLAY
                       ↓
                    PLAY_DEAD
                       ↓
                BETWEEN_BATTERS
```

Additional transitions:

- 3 outs → INNING_TRANSITION
- game complete → GAME_END

UI/animation observes game state.

Presentation does not create authoritative game state.

---

# 52. Core Event Flow

```text
PitchCommand
    ↓
PitchLaunchBuilder
    ↓
PitchFlightSolver
    ↓
SwingIntent
    ↓
ContactResolver
    ↓
BattedBallLaunch
    ↓
BattedBallBody
    ↓
BallPlayResolver
    ↓
BallPlayOutcome
    ↓
BaseState / MatchState
    ↓
Presentation
```

This is the central gameplay pipeline.

## Match cadence and presentation

Dead-ball holds are state-driven and advance automatically. They use separate
bounded timing ranges for another Pitch in the same plate appearance, a new
batter, and an inning transition. A completed player-offense plate appearance
returns to a one-time Batter-ready confirmation before the opponent begins its
delivery; subsequent Pitches in that plate appearance need no confirmation.
This is the future pre-at-bat consumable/tactical boundary. On defense,
completion of the hold returns
the player to `PRE_PITCH`; the player controls tempo by choosing when to begin
the next delivery. On offense, the opponent delivery director begins its own
bounded set/windup cadence. `AtBatCadenceController` separates a quiet setup
hold (0.22–1.05 s, with an 18% chance of another 0.35–0.70 s) from the existing
1.12–1.78 s windup. The pose stays at progress zero during setup, then advances
smoothly through the windup. Both draws are seeded; dead-ball holds are unchanged.

Hardening prioritizes smooth, readable transitions over shortening this loop.
Extra acceptance input cannot skip a result hold. Debug pause freezes the
release meter, live actors, and cadence. A Pitch-button release during pause
cancels only an active uncommitted player delivery, with no throw or Stamina
cost. A rejected Mechanics Lab transition must preserve the paused state.
Safe transitions restore the pre-pause status before suspending the match.

Paused inspection accepts `V` and updates only camera interpolation/follow.
It cycles all nine authored views without advancing physics, Swing presentation,
match time, delivery cadence, or intro/outro time. Resuming restores the prior
shot through normal smoothing; a setup screen closed during inspection instead
restores its gameplay shot. Bat and Batter actors are explicitly pausable even
though the lab root must always process debug input and camera inspection.

Esc is the sole keyboard pause shortcut; it backs out of nested settings/setup
where applicable. Intro skip uses click/Space. `T` requests one Batter timeout
per plate appearance during the AI's quiet set only. It stops cadence, preserves
the preselected Pitch/target, and requires readiness confirmation to restart.
It cannot cancel an active windup or flight. Normal pause remains unlimited.

For player pitching, Pitch selection, target, effort, Pitcher/Primary Fielder
roles, and the Primary Fielder anchor are mutable only in their legal ready
states. They lock when the release meter begins and remain immutable through
Pitch flight and ball-in-play.

Pitching Staff and Field Setup shield the Pitch target from pointer and
continuous aiming input. Escape backs out of Settings, then resumes Pause,
then returns from defensive setup through the normal role-camera path.
At a normal gameplay boundary Escape opens Pause. `_input` also handles paused
Pitch-button releases before GUI consumption, preventing a menu click from
leaving an abandoned delivery armed.

`MatchPresentationDirector` is a match-local presentation state machine. It
selects one, two, or three unique, seeded intro shots from an authored
pool, uses a longer duration for a one-shot take, deliberately varies the
package length between matches, uses readable holds,
blocks gameplay during the sequence, returns through the correct role camera,
and exposes a skip path. Each shot also receives a seeded, bounded motion mode:
still, zoom in/out, pan left/right, or tilt up/down. `MatchCameraDirector`
applies that motion to the authored shot transform without changing game time.
The win/loss result uses a separate infinite scenic loop, described below.
The presentation director observes `MatchState`; it does not own innings,
scores, results, or gameplay timing. High-stakes cinematic packages remain a
future extension of this director, not a second match state machine.

`MatchCameraDirector.prepare_ball_in_play()` receives the current player role
before switching shots. Player defense initializes the follow camera on the
pitching side, then raises/pulls back and tracks the live ball without crossing
to the Batter's side. Player offense retains the behind-the-Batter follow.
Camera interpolation changes presentation only and cannot affect ball physics
or fielding resolution.

`PitchBatLabHomeRun` handles scored-ball presentation separately from resolution:
the real body carries beyond the wall for 1.25 s, with scoring callbacks
disconnected, then freezes as the camera smoothly switches to Establishing.
The Home Run call lasts 4.4 s total; even a walk-off waits before the outro.
Pause freezes the carry and timer. Reset/cleanup cancels the sequence. Live-ball
tracking follows more of the ball's horizontal/depth travel and gains vertical
range; batting camera height is 2.10 m with a slightly lower target.

Match HUD ownership is split by purpose. `MatchScorebug` renders persistent
baseball state from `MatchState` at a user-selectable bottom-right, top-left, or
top-right anchor. A small boxless label beneath that anchor renders routine
Ball/Strike/Foul and speed telemetry. Larger transition/result messages render
above center at 26 px with dark-blue outline/shadow. `PitchPicker` renders the
current repertoire as numbered buttons and owns Pitch count, Stamina and fatigue
stage on player defense. The 252 px panel uses one-line numbered rows, preserves
readable text and selected state, and collapses to the selected Pitch when
delivery locks selection. It hides during Home Run presentation. Field/Bullpen
toggle buttons are 132 px wide; footer text ends above the Pause button. The scorebug
retains opponent condition during player batting. `PitchBatLabPauseMenu` nests
HUD-anchor, blue-sky/green and Mute sounds choices inside Pause. `PitchBatLabSettings` saves
them in `user://display-settings.cfg`. Batting zone opacity is 0.35 and aim
outline opacity is 45% of its original value; pitching materials are unchanged.
F1-owned labels render detailed
diagnostics. F2 may enter the
Mechanics Lab only at a safe stopped pre-Pitch boundary. The Lab keeps the
existing `MatchState` suspended and restores its selection/aim/role-facing
presentation state on return; it never creates a replacement match merely to
leave debug mode.

HUD research references: Microsoft's [text-display guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
emphasizes readable size, spacing and player context; its [contrast guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102)
addresses information against changing backgrounds. The compact redesign removes
repeated delivery labels and unused rows before reducing text size. These are
design references, not a claim that headless layout checks establish visual
accessibility compliance. Rendered review is still required.

AI chase behavior uses a gradual outside-zone probability falloff: borderline
balls invite offers, two strikes add protection, and far waste pitches remain
mostly takes. In-zone swing, contact-aim and timing formulas are unchanged.

---

# 53. Event Architecture

Use a match-local event hub for important gameplay events.

Potential event vocabulary later includes:

- PitchReleased
- PitchResolved
- SwingStarted
- ContactMade
- FirstGroundContact
- ZoneEntered
- ObstacleHit
- FielderContact
- BallControlled
- OutRecorded
- Strikeout
- RunnerAdvanced
- RunScored
- InningEnded
- GameEnded

Do not implement every event before a real subscriber exists.

The future modifier system should extend this architecture rather than bypass it.

---

# 54. Explicit Non-Goals for Initial Core

Do not build yet:

- physical runner AI
- throw-to-base simulation
- manual fielding
- authoritative physical bat collision
- rigid-body Pitch flight
- global gameplay EventBus
- full shop/economy
- League system
- persistent stadium system
- multiplayer
- giant custom content editor
- production art pipeline beyond what the Lab needs

---

# 55. Phase 0–3 Engineering Backlog

## Phase 0 — Foundation

1. initialize Godot 4.7.2 project
2. Mobile renderer
3. Jolt
4. physics interpolation
5. Git/GitHub
6. folder structure
7. typed-GDScript warning policy
8. collision-layer convention
9. docs committed
10. stable ID utilities
11. DefinitionBase
12. ContentManifest
13. ContentDB
14. PlayerDefinition
15. DeliveryProfileDefinition
16. PitchDefinition
17. BallAeroProfileDefinition
18. BallSetupDefinition
19. runtime PitchState
20. PitchLaunchParameters
21. coordinate/unit conventions
22. minimal debug-draw helpers

### Phase 0 acceptance

A Pitch can be fully authored as data and resolved through ContentDB without changing simulation source code.

---

## Phase 1 — Pitch/Bat Lab

1. semantic pitcher-relative frame
2. handedness mapping
3. fixed-step RK2 Pitch solver
4. gravity
5. drag
6. spin lift
7. perforation/asymmetry force
8. orientation integration
9. sphere/shape sweep collision
10. visible Pitch actor
11. trajectory trace
12. plate/strike zone
13. Four-Seam prototype
14. Sinker prototype
15. Slider prototype
16. Riser prototype
17. Drop prototype
18. Eephus prototype
19. Knuckle prototype
20. PitchAimSolver
21. execution/fatigue perturbation
22. SwingProfileDefinition
23. Contact Swing
24. Power Swing
25. SwingIntent
26. ContactResolver
27. spray output
28. launch-angle output
29. exit-velocity output
30. batted-ball spin output

### Phase 1 acceptance

- Overhand Sinker and Sidearm Sinker are authored separately as data.
- They produce visibly distinct release/flight.
- Identical launch inputs reproduce the same sampled trajectory.
- Aim refers to intended plate crossing.
- early/on-time/late contact trends toward pull/center/opposite.
- Contact and Power swings feel mechanically distinct.

---

## Phase 2 — Ball-in-Play Lab

1. BattedBallBody
2. Jolt CCD
3. custom batted-ball aero
4. starter graybox field
5. safe-hit boundary
6. deep Double region
7. back wall
8. HR boundary
9. mathematical crossing tests
10. BallPlayState
11. BallPlayResolver
12. Single
13. deep-air Double
14. bounce-to-wall Double
15. wall-on-fly Triple
16. Home Run
17. 3×3 tactical grid with field-authored legal anchors
18. trajectory predictor
19. FielderPlanner
20. FielderController
21. FieldingResolver
22. clean/bobble/miss
23. DeflectionModel
24. Pitcher defense
25. BaseState
26. ghost advancement
27. TagAdvanceResolver
28. sacrifice-fly behavior

### Phase 2 acceptance

A single hit can travel through physical 3D space and resolve coherently as Out/Single/Double/Triple/HR while the automated fielder and Pitcher defense visibly react.

---

## Phase 3 — Complete Vanilla Match

1. four-player roster
2. fixed batting order
3. batter changes
4. Ball/Strike/Out counts
5. walks
6. runs
7. innings
8. pitching changes between batters
9. Primary Fielder changes between batters
10. Stamina
11. fatigue/hangers
12. pitcher re-entry
13. five-inning structure
14. 10-run mercy after three completed innings
15. extra-inning runner on second
16. game-over state
17. match timing telemetry
18. role-aware batting / pitching / ball-in-play cameras
19. current and on-deck batter presentation
20. visible pitch count, Stamina, bases, and complete count
21. shared Match Mode / Mechanics Lab debug layer
22. bounded per-pitch effort control
23. action-mapped keyboard/controller aim, swing, advance, and release inputs
24. player-timed release with Control- and fatigue-sensitive timing windows
25. count-aware deterministic opponent pitch and swing decisions
26. smooth role and ball-in-play camera direction
27. deterministic per-play records for reproduction and tuning
28. headless core regression scene
29. one-confirmation-per-Batter flow, automatic within-at-bat dead-ball cadence,
    and Pitcher telegraph
30. pointer-projected Contact/Power Swing input
31. pausable debug inspection
32. visible four-player pitching-staff selection between batters
33. nonlinear fatigue-band and plate-reach regression coverage
34. handed Batter/Pitcher/Fielder presentation and visible bat swing
35. deterministic Batter approach memory without hidden-input reads
36. plate-plane mouse pitching through the shared hold/release execution meter
37. bounded delivery-rhythm variance
38. overhead 3×3 Field Setup view
39. mathematical back-wall segment fallback
40. independent BatActor presentation and post-plate visual catch-through
41. 240 Hz swept Pitch-versus-moving-contact-region resolution
42. missed-swing continuation through plate call and receiver presentation
43. faster authored Swing and player Pitch-release timing
44. automatic one-to-three-shot game intro and win/loss outro
45. state-safe presentation skipping and role-camera settlement
46. future high-stakes broadcast package seam without baseball-state ownership
47. seeded per-shot still / zoom / pan / tilt presentation motion
48. compact lower-right `MatchScorebug` plus boxless beneath-scorebug event ownership
49. safe-boundary Mechanics Lab suspension that preserves the live `MatchState`
50. late release sweet spot and bounded category-aware overdrive tradeoff
51. release-driven visible player-Pitcher delivery pose

### Phase 3 acceptance

A complete vanilla game can be played repeatedly with no roguelike systems and is fun enough to justify building the season layer.

---

# 56. Production Gate

Do not implement the full roguelite until the vanilla sport clears this gate.

Questions:

- Is throwing Pitches fun?
- Can the batter read and react to them?
- Do Contact and Power swings create useful choice?
- Does fielder positioning matter?
- Are hit classifications understandable?
- Do bobbles/deflections read clearly?
- Is pitching fatigue interesting rather than merely annoying?
- Is a five-inning game an acceptable length?
- Do players want another at-bat/game?

If the answer is no, fix the sport before building shops and meta progression around it.

---

# 57. Technical Risks to Monitor

## Pitch readability

Movement can be physically interesting yet impossible to read.

This is a gameplay/tuning risk, not an engine-limit assumption.

## High-speed collision

Thin geometry may require simplified/thicker gameplay collision proxies even with CCD.

## Fielder prediction

Later absurd rebounds may require more frequent re-planning, not a perfect prediction model.

## Mobile

Rendering/animation/crowds are more likely to become mobile bottlenecks than one-ball aerodynamic simulation.

Test real phones early.

## Animation

Multiple delivery slots and handedness are a production-workflow risk to monitor once character animation begins.

None is currently a repo blocker.

---

# 58. Testing Direction

Before large-scale gameplay systems exist, prioritize pure logic tests for:

- stable ID/content lookups
- Pitch solver repeatability
- timestep convergence
- strike-zone crossing
- contact resolution
- swept Swing timing and miss continuation
- BaseState advancement
- BallPlayResolver
- sacrifice advancement
- match-state transitions
- release timing quality and stat/fatigue influence
- count-aware opponent decision determinism
- JSON-safe per-play record serialization
- automatic dead-ball cadence and presentation-director sequencing

Physics-heavy behaviors should also have small regression scenes with known expected ranges rather than relying only on unit tests.

The core regression scene runs with:

```text
godot --headless --path . res://src/tests/core_regression_test.tscn
```

---

# 59. Developer Tooling Direction

The first important tool is the Lab itself.

It should eventually expose:

- Pitch selection
- Pitch coefficients
- release slot
- velocity
- spin
- orientation
- ball setup
- trajectory trace
- strike-zone crossing
- contact-debug values
- batted-ball launch vector
- fielder coverage
- field-rule boundaries

Do not build an elaborate generalized editor before tuning proves which controls matter.

---

# 60. Architecture Freeze

For repo initialization, the following is considered settled:

```text
Engine:
Godot 4.7.2

Language:
typed GDScript

Renderer:
Mobile

Pitch:
custom fixed-step simulation
Node3D presentation
shape sweeps for collisions

Contact:
mathematical arcade resolver

Ball in play:
Jolt RigidBody3D + CCD + custom aero

Fielding:
planner/resolver + CharacterBody3D presentation

Baseball rules:
pure/state-machine logic

Content:
immutable Resource definitions

Runtime state:
RefCounted classes where practical

Presentation:
Nodes/scenes/animation

Global state:
minimal Autoloads

First real target:
Pitch/Bat Lab
```

Any deviation should be driven by an observed implementation problem, not hypothetical architecture anxiety.


## Development verification and QC persistence

`tools/setup_verify.py` provisions pinned Godot 4.7.2 and gdtoolkit 4.3.4.
`tools/verify.py` checks an isolated current-source copy, preserves logs, and
fails on engine errors even with a zero process exit. See `VERIFICATION.md`
for commands, supported setup platforms, and current runtime findings.

`PlayRecordExport` saves completed-play snapshots under `user://qc/`. F3
retains console output and reports the saved path; resetting rotates the file
without removing earlier sessions. Records retain match/lab provenance and
snapshots retain loaded geometry, engine version, and available Git metadata.
This is development telemetry, not a gameplay save system.

The verification runner also executes seeded full-match state transitions,
two scripted-player live-scene matches, live player-input flow checks, and
isolated Jolt ball fixtures. These test reliability and collision-to-rule
integration, not a representative result
distribution. PitcherDefense must allow a grounded ball center down to world
height zero; a 5 cm lower gate excludes the authored 3.65 cm-radius rolling ball.
Negative-height positions remain ineligible. No mound radius or control
threshold changes accompany this correction.


## Presentation feedback follow-up — 2026-09-21

`PlaySounds` caches five original mono PCM cues in `AudioStreamWAV` resources,
played by pausable `AudioStreamPlayer` children at -12 dB. Contact, clean control,
bobble, wall and HR hooks observe authoritative events; audio never resolves play.
There are no third-party sound files, downloads, attribution obligations from
new assets, or runtime synthesis on the contact frame. `audio/muted` shares the
existing settings file, defaulting false for older files. Muting immediately stops
all cues, including paused playback, and new muted cues are discarded.
Accelerated headless fixtures allow two real mixer/update cycles at teardown,
so engine shutdown does not race queued audio cleanup. There is no gameplay wait.

`BallVisibility` owns a soft ground-reference shadow and a tapered transparent
ribbon made from recent actual batted-ball positions. It has no collision shape,
resolver calls, predictive trajectory, or Pitch-flight attachment. The ribbon
requires speed >=12 m/s and is bounded to 65 ms and 0.9 m. It clears on slow/frozen
balls and on cleanup; the shadow is hidden beyond the back wall and near ground.
The lab's paused update gate freezes history while allowing camera inspection.

`PitchFeedback` renders one 14 px, three-second note beside the scorebug, with a
short fade, no mouse interception, and no overlap with the routine call slot.
Top-left Pitch panel and top-right defensive buttons move down to make room.
Pitch calls live in `PitchBatLabPitchCall` to keep the main lab below its lint
size limit. Handedness/feedback are captured before the count resolver advances
the Batter, and miss feedback is taken from `ContactResult`. Repertoire tooltips
read `PitchDefinition.tactical_description`; descriptions reflect the authored
starter content rather than promising a real-world trajectory or guaranteed result.

The existing cadence still owns progression. Catch/strikeout holds have a 2.25 s
minimum, longer inning holds retain priority, and non-HR immediate game endings
hold for 2.5 s before outro. HR remains 4.4 s. Bobble feedback never pauses physics.
No field boundaries, transfer functions, aerodynamic coefficients, fatigue model,
AI odds, or windup durations changed in this pass.

### Sources and design interpretation

- [Godot AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html)
  documents generated PCM storage; [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)
  documents nonpositional playback and stop/pause control. These support the small
  cached cue implementation. The waveforms themselves are project-original code.
- [Godot Control](https://docs.godotengine.org/en/stable/classes/class_control.html)
  documents `tooltip_text`; the existing hover interaction provides optional
  descriptions without introducing a hold action or changing Pitch inputs.
- [Xbox XAG 103: Additional channels for visual and audio cues](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103)
  supports retaining text/visual equivalents for audio and not relying on color
  alone. The existing Stamina percentage/condition remains beside a bar that turns red
  at 17% remaining; the user requested no added warning text. Live bobbles retain
  a text label alongside their sound.
- [Xbox XAG 105: Audio accessibility](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/105)
  supports player control over sound. This prototype has one effects category and
  one saved mute toggle; separate category levels can follow if music/voice arrives.
- [Xbox XAG 117: Visual distractions and motion](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117)
  informs the restrained approach: no flashing warning, shake, or motion blur.

These sources inform implementation and accessibility choices. They do not
validate the chosen trail length, volume, result timing, or fun. Headless tests
cannot establish visual comfort, sound quality, or accessibility conformance;
rendered play and human listening remain required.

## Final sport audit and Season Shell — 2026-09-21

The initial full Godot 4.7.2 baseline passed at `5c22c22`. The new camera audit
then reproduced loaded-bat AABB intersections with three sampled incoming rays
per hand at the former 0.34 m camera-side offset. Reducing it to 0.18 m clears
all 90 sampled rays per actor across the two hands. This is a conservative mesh
bounding-box test at the loaded, centered-aim pose, not rendered pixel occlusion
or exhaustive aim/swing coverage. Height 2.10 m, depth -3.38 m, focus
`(0, 1.10, 7.1)` and 75-degree FOV remain; projected one-meter zone height is
about 132 px in the 1280×720 viewport. The camera stays stable during a Pitch;
the contact-plane pointer mapping round-trips at `ContactResolver.CONTACT_PLANE_Z`.
No broad camera or sport tuning was introduced.

That audit aligned `BatterApproachModel` and `PitchFeedback` with the old scene,
but did not verify baseball handedness from the camera. The follow-up below
supersedes that mapping: the old scene itself had its batter boxes reversed.

### Season boundaries

- `SeasonState` owns draft choices, the six-team circle schedule, league results,
  standings and playoff transitions. It creates `MatchState` from immutable
  authored `PlayerDefinition` resources; live play continues through the existing
  match/contact/physics pipeline. The 24 new starter players are manifest entries.
- `SeasonApp` owns main/menu/match scene lifetime. `SeasonMenu` supplies simple
  scrollable body pages with persistent footer navigation. Menus have no Pitch
  input handler; an active lab receives only unhandled gameplay input.
- `_player_home` drives role checks and the correct win/loss presentation.
  The configured match is consumed once. Menu-managed games reject `R` restart;
  standalone lab regression/debug behavior remains available.
- Result recording is guarded by the current fixture ID and a one-shot app
  flag. Final scores save during GAME_END; the existing presentation completes
  before Continue opens postgame. Pause > Leave confirms abandonment of an
  unfinished fixture. Finished games use the result handoff instead.
- New `SeasonSave` uses `user://season-v1.json`, a temporary write/flush/rename,
  versioned JSON primitives and stable player IDs. Only seed, draft picks,
  player-game scores and lineup selections are stored. Loading validates bounds,
  IDs, legal pick/result order, unique lineup and distinct defense roles, then
  reconstructs derived standings and AI scores. Corrupt/incompatible files are
  reported and left untouched. No midgame or career persistence is implied.
- Reconstruction assumes this version's content pool and simulation rules.
  Content-pool/algorithm changes require an explicit save-version migration or
  invalidation policy; silently reinterpreting an old season is unacceptable.
- AI-only games use seeded Poisson scores based on the average of the authored
  seven player ratings, with a seeded tie resolution. They do not run physical
  Pitches, use player standing for rubber-banding, or supply calibration evidence.
- Wins, run differential, runs scored and a seeded preseason draw are provisional
  tiebreaks. Every match starts with fresh player states. The neutral final has
  nominal home/away roles for inning rules and the starter field as placeholder.

### Implementation sources

[Godot saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
documents JSON serialization and the `user://` path.
[Godot DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html)
documents file replacement through `rename_absolute`. These support the save
mechanism; the schema validation, replay design and season policies are project
decisions. The single-file checkpoint is not a cloud save or power-loss durability
guarantee. Save errors remain visible and the live session stays available.

## Season enrichment follow-up — 2026-09-21

See `SEASON_ENRICHMENT_AUDIT.md` for the ten-point audit, primary research,
decisions, measured evidence and scope boundaries.

- `SeasonPlayerCard` presents identical seven-stat rows on draft cards;
  `SeasonMenu` provides explicit selection then confirmation, a persistent
  chosen-roster strip, a visible lineup grid and focusable navigation. Ratings
  do not rely on hover, color or a single overall score.
- `PlayerDefinition` adds `switch_hitter`, `pitching_style` and
  `signature_pitch_index`. Pitcher handedness remains the existing R/L enum.
  `PlayerMatchState.batting_hand_override` is mutable match state, never a
  mutation of the shared Resource. Contact, bat, avatar and feedback read it.
- With home at Z=0 and field at +Z, the catcher's camera's screen-right basis
  points toward world -X. Right-handed Batters must therefore stand at +0.82 X,
  left-handed Batters at -0.82 X. Bat rig signs and the small camera offset mirror
  with that correction. The previous audit only tested mutual consistency and
  missed the reversed baseball convention. New camera tests assert screen side.
- `MatchRosterControls` exposes the real Primary Fielder and rating in Field
  setup, applying the same between-Batter guards as F. Its switch-hitter control
  is available only before initial readiness. Once the AI pitch plan is selected,
  even a timeout cannot unlock a side change for that plate appearance.
- `BatterApproachModel.track_pitch` samples visible velocity changes to estimate
  acceleration, builds an early timing plan, then applies bounded aim correction
  from a 65 ms delayed read. Extrapolation is capped at 0.32 s. It does not call
  the aim solver, future integration or hidden target. Decisions run on flight
  substeps, and all swings share `SwingIntent` aim bounds. Execution errors remain;
  F3 gains `ai_plate_read`, effective `batter_hand` and fixed `pitcher_hand`.
- `PitchingStrategy` is a seeded weighted-choice model using only owned Pitches,
  authored style/signature, count, previous-Pitch nominal speed and batting hand.
  Difficulty affects edge/expansion/sequencing weights, not ratings or command.
  Match tactical quality is `clamp(0.15 + difficulty*0.25 + min(round,9)*0.025)`.
  Legacy save values 0/1/2 retain Relaxed/Standard/Tactical semantics. New seasons
  now use 1 (the unchanged Standard baseline), presented as Base. This historical
  field is not a future per-League tier/unlock system. Effort is 0.94–1.04.
  Pitcher substitution clears the previous-Pitch index rather than interpreting
  an old arsenal index as a different player's Pitch.
- Forty-eight explicit manifest players supply a randomized season pool.
  A deterministic swap keeps at most one >=4-Pitch player in the first twelve
  draft offers, without duplicating/removing anyone. Twenty-four players occupy
  the six active clubs; the rest are absent that season.
- Save schema 2 freezes ordered pool IDs, tiebreak draws, difficulty and the
  six AI simulation strength values alongside picks, lineup and player results.
  Full-precision JSON avoids rounding the replay inputs. Schema 1 recreates its
  original sorted 24-ID pool before replay. Future score-algorithm changes still
  require explicit migration. Player definition balance itself is not snapshotted.
- Before replacement, a valid primary save is copied to `.bak`. A corrupt or
  absent primary may restore that backup with a visible recovery notice; it is
  not silently called current progress. Invalid primary data stays untouched
  until a later deliberate checkpoint. Both invalid files produce an error,
  not a fabricated new season. File name remains `season-v1.json` for continuity;
  the JSON version, not the filename, identifies the schema.

Persistence remains local and between-game. Midgame suspension requires explicit
serialization of count, batting cursor, used Pitchers, Stamina, tactical state
and physics/presentation boundaries; it is not implemented as a quick scene dump.

## Season flow and performance follow-up — 2026-09-21

`SeasonPages` owns hub/pregame/recap/statistics presentation. `SeasonMenu` keeps
the shared frame, persistent footer, draft and editable roster. The main route
is hub → pregame → match → postgame → next pregame, with a separate season-ending
recap. Current opponent starter information reads the same roster index used by
`SeasonState.make_match`. Standings movement compares complete league rounds;
the preseason tiebreak draw is not presented as movement after the first game.

`MatchPerformance` observes completed plate appearances at the existing
`MatchState` scoring methods, before batter advancement and game-end handling.
It never resolves a play. Hits, walks, strikeouts and sacrifice scoring therefore
use authoritative results. Pitch counts come from each `PlayerMatchState` at
snapshot time. Match/Lab suspension retains the same MatchState, so clearing
development telemetry cannot erase gameplay statistics. No ERA or individual
runs are inferred from ghost runners or inherited runners.

`SeasonApp` submits a deep performance snapshot with the fixture's final score.
`SeasonState.record_player_result` validates it before mutation and retains it
in the same single-commit result. Unfinished games never enter season totals.
`SeasonPerformance` validates roster IDs, integer bounds, hit-type bounds and
balanced batting/pitching totals, aggregates player IDs and finds tied leaders.

Save schema 3 keeps schema 2's replay inputs and embeds optional statistics in
completed player results. Version 1/2 histories remain score-only, with visible
coverage. Mixed older/newly recorded seasons remain valid. The existing valid
backup and temp/flush/rename mechanism is retained. There is no midgame resume,
career history or simulated AI box score. Full-season statistics are a sum of
saved completed-game observations, including playoffs.

The new flow test covers real scoring-method attribution, substitution,
walk-off, a twelve-game scored season, save/reload and malformed stats, older
save migration, page bounds and scroll preservation. The live drafted-match
test additionally checks that actual AI/contact/Jolt events yield balanced
statistics and one observation per completed appearance. Human visual/feel QC
remains necessary; headless layout checks do not establish aesthetics.

## Pause inspection and home/away venues — 2026-09-22

`MatchStatsPanel` is a pause-only read view owned by the existing HUD canvas.
It reads immutable player definitions and a deep `MatchPerformance.snapshot`,
without changing roles, results, saves or gameplay state. Its scrollable body
switches teams and rating/box-score pages; the Back footer stays fixed. Escape
first closes inspection, then the existing pause control resumes play. Remaining
Stamina and used-arm flags are current match state, separate from Stamina rating.

`SeasonState.field_for_fixture` selects the existing `field.starter_backyard`
(now displayed as Yard Club Field) when the player hosts, otherwise
`field.commons_park`. A neutral final always uses Commons Park. `SeasonApp`
passes that ID before `PitchBatLab._ready` builds geometry. The actual loaded
FieldDefinition reaches defenders, ball resolution, intro and F3 metadata;
pregame uses the same selector. Exhibition/standalone Lab retain the original
field by default. Venue derives from the saved fixture, so schema 3 is unchanged
and older saves continue with deterministic venue selection.

Both definitions keep identical scoring dimensions, legal anchors and collision
shapes. `CommonsParkScenery` adds a distinct turf/wall palette, stripes,
bleachers, dugouts, a clubhouse and park sign as noncolliding presentation.
Scenery is outside the central pitch corridor; no new obstacles, bounces,
physics settings or field-rule modifiers are introduced. Rendered comfort still
requires human QC; the development environment has no display/Vulkan renderer.

`MatchRosterControls` places the switch-hitter button/cue beside readiness and
handles B in match mode (the Mechanics Lab keeps its existing B debug action).
The shared legality check rejects intro/outro, pause, delivery and timeout
reselection. Viewport-dispatched mouse input verifies that clicking this GUI
control consumes the event instead of confirming the at-bat underneath it.
`PlayerMatchState.batting_hand_override` remains the one effective batting-side
source; it never changes the definition's throwing hand.


## Ratings access and ball-tracking visibility — 2026-09-22

`SeasonPages.players` exposes all four player definitions read-only from the hub,
season recap and performance page. `SeasonPlayerCard.ratings_card` is shared with
pause inspection so rating order, hands and full repertoire labels agree. Bullpen
rows show the actual throwing hand, not the effective switch-hitting stance.

`BallTrackingVisibility` caches world bounds of the current wall, live pole and
Commons Park decorative meshes after environment construction. This deliberately
includes noncolliding scenery; it is a bounded static-venue presentation helper,
not a new physics collision or generic dynamic-occluder framework. If the camera
ray is blocked, it reduces horizontal distance toward an elevated ball-relative
position, with a small clearance margin. Both desired and interpolated tracking
positions are checked. A field-aligned up axis supports overhead views without
flipping to the other team's perspective; an on-screen guard keeps the physical
ball framed. The normal interpolation restores distance when clear. Only live
ball tracking changes; pitching/aiming views, sport geometry and dynamics do not.
Future structural/scenery changes must refresh the cached bounds and extend the
visibility fixtures. Rendered smoothness and comfort still require human QC.

New seasons expose only Base while retaining schema-3 legacy difficulty values
and saved AI snapshots. Overall per-League progression, a small initial League
set and later League/tier unlocks are accepted design requirements for Phase 6,
not implemented persistence or gameplay. Field grandeur/progression is likewise
an accepted roadmap goal; no new dimensions or adaptive scaling are introduced.


## Infinite result camera loop — 2026-09-22

`MatchPresentationDirector.OUTRO_HOLD` now means a continue-ready result with
rolling cameras, not a static view. Four seeded scenic angles repeat indefinitely
with non-still zoom/pan/tilt motions and 10-second shot clocks. Result transitions
use a slower camera interpolation rate (0.8 versus the normal 7.5); intro and
live-play transition rates are restored through the existing motion reset/sync.
The 1.7-second readiness gate preserves a short settlement without making players
watch a complete cycle. Entering or skipping to the ready state preserves the
current motion clock. `SHOT_CHANGED` remains active in the hold state, while
`SeasonApp` keeps Continue available and its existing once-only save guard.
No match rules, pitching, ties or season reward/progression mechanics change.


## Shared clubhouse menu presentation — 2026-09-22

`ClubhouseTheme` owns the menu palette, surfaces, control states, primary action
styles, table cells and typography colors. `ClubhouseBackdrop` draws lightweight
field-line decoration behind the season layout and ignores pointer input.
`ClubhouseMenuStack` supplies an opaque background around existing Bullpen and
Field containers without changing their node ownership or callbacks. Gameplay
controls retain compact type sizes and their original legal-action guards.

Season and pause player cards use the same ratings renderer. Season/per-game
stat tables use alternating rows; values and save data are unchanged. Schedule
cards read existing fixture/results and display venue and status. Confirmation
and Continue controls use the shared theme. Pause focuses Resume when opened;
Settings focuses its first option and all pause actions support normal GUI
keyboard activation. Escape retains the existing panel/pause/resume order.

Pinned Godot and toolkit versions are unchanged. Automated layout and input
checks are evidence of geometry/behavior, not rendered visual approval. This
environment cannot establish a display socket, so an attempted portable visual
preview could not render screenshots. Human desktop QC remains required.


## Reconstructed ownership and result persistence, 2026-09-28

SeasonOwnership evaluates commands against a deep candidate snapshot before publication.
Revision-bound, unique request identities distinguish an idempotent retry from conflicting
reuse. Completed reward identities cannot pay twice. Purchase receipts derive full actual
price from immutable presented stock, explicit replacement may fund itself with sale proceeds,
and final held/sponsor capacities are validated after explicit discards and removals. No
intermediate owned spare is published. Queries return detached copies. Journal replay rejects
unknown fields/events, duplicate saved commands, fractional/invalid values and catalog changes.
Catalog fingerprint migration is deliberately gated rather than silently repricing receipts.

SeasonState pays Working base18/12 Cash once per validated fixture. Schema4 adds ownership;
production currently accepts only the exact reward journal derived from player_results, since
real shop generation/effect contracts remain missing. Schema1–3 histories migrate in memory.
Save validation runs before touching the previous checkpoint. SeasonApp tracks recorded versus
saved results independently; Continue offers RETRY SAVE after a write failure and does not
record or pay again. Unfinished matches cannot settle through the app's result boundary.

OwnershipLab is a separate synthetic transaction UI with exact added/removed receipt previews,
confirm/cancel, capacity failure, explicit disposal and isolated test snapshots. Its fixtures
are not production item definitions. SeasonOwnershipStore validates/replays those snapshots,
uses temporary-file replacement and last-valid backup, and leaves corrupt primary bytes intact
on read. None of this restores the lost four-stat, sponsor-effect, career or offscreen modules.
