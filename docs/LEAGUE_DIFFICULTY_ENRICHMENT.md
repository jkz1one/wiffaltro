# League, difficulty and progression: next decision pass

2026-09-22. Design preparation after the human-QC camera/menu corrections.
Source v0.4.29 remains authoritative. This packet does not implement unlocks,
authorize Phase 5 gameplay, or treat automated verification as human approval.

## Accepted direction

- League is the Deck analogue: an understandable structural identity chosen
  before the run and retained for the season.
- Difficulty is the Stake analogue: overall pressure with an independent unlock
  ladder for each League. Only Base starts unlocked in each available League.
- Start with a small unlocked League set and earn additional Leagues.
- Calendar progression develops recognizable opponents and makes the stretch
  run/playoffs consequential. It does not rubber-band against the player's record.
- Later venues can become grander; selected advanced parks may also become
  larger after build design and human QC. Keep pitching geometry/feel stable.
- Home structural development happens between seasons, with an Opening Day lock.
- The implemented shell remains Backyard/Base, with the previous Standard AI
  tactical baseline. Historical saved tactical presets retain their behavior.
- Current games cannot end tied: extras after five innings, a ghost runner on
  second in each extra half, and normal home walk-offs. Standings tie resolution
  currently uses run differential, runs scored and the saved preseason draw.

## Recommended decisions to review, not frozen requirements

| Decision | Starting recommendation | Reason / unresolved work |
| --- | --- | --- |
| Initially available Leagues | Two | Offers a meaningful choice without a large launch matrix. Second identity must be authored; don't ship a renamed duplicate. |
| Difficulty launch scope | Four tiers including Base | A bounded ladder for readable, testable pressure combinations; reduce it if the effects cannot support meaningful differences. |
| Next tier unlock | Win the championship at the preceding tier in that League | Uses an unambiguous run outcome. No cross-League tier unlock, loss penalty or mandatory repeat clear. |
| Extra League unlocks | Start by testing the first additional League after a first championship | Additional milestones and catalog size depend on how distinct the authored rules are. Avoid grinding the same run merely to reveal basic variety. |
| League versus tier | League changes what a build values; tier changes the pressure under those rules | Every League should support several builds. A League should not just be a harder park or higher enemy stat sheet. |
| Tier pressure | Prefer one clear headline rule per tier, with a short preview of all active rules | Whether effects accumulate must be explicit. Economy numbers and opponent upgrade budgets wait for the Phase 5 catalog. |
| Calendar pacing | Opening, midseason, stretch run, playoffs | Author recognizable opponent improvements and stakes for those stages. Do not assume the current pitching-only weight is the finished curve. |
| Venue pacing | Growing presentation prestige; selected authored mechanical variations | No automatic fence movement after buying Power, and no requirement that every later venue be bigger. |

These counts and unlock milestones are new design proposals, not tested balance
or claims about another game's optimal design. Human approval should choose the
rules before any progression implementation starts.

## Authoring order

1. Define the identities of the initially available Leagues. Each needs a clear
   rule summary, what it teaches, several viable build directions and explicit
   exceptions to the base rules. Keep one reliable reference League.
2. Define the tier ladder and unlock conditions for those identities. Distinguish
   normal calendar development from additional tier pressure; preview the full
   effective rules before confirming a season.
3. Author the initial build catalog, opponent progression budgets and reward/shop
   cadence together. Consumables still need their acquisition, inventory, timing,
   duration and targeting decisions. Effects determine required runtime hooks.
4. Author the venue sequence against those builds: separate presentation changes
   from scoring/geometry changes, and identify bounded experiments for later QC.
5. Approve a small integration slice and its acceptance cases, then implement the
   minimum definitions/checkpoint changes needed by those actual rules.

## Minimum future infrastructure contract

This is a compatibility checklist for the approved slice, not a request to build
a generic modifier engine now.

- Stable League and difficulty IDs. Do not repurpose the existing integer
  `difficulty` tactical preset as an unlocked-tier index. Use an explicit migration
  that preserves an in-progress legacy run's tactics, roster and results.
- A run records its selected League/tier and applicable rules version. Continue
  resumes those rules; installing newly authored content must not silently change
  the active run. Decide the minimum snapshot needed once actual effects exist.
- Persistent progression records available Leagues and cleared tiers per League,
  separately from temporary run power. New unlocked Leagues begin at Base.
- A stable run ID and idempotent clear credit: reopening the result screen,
  watching its camera loop, restarting the application or loading a backup must
  not grant the same clear twice. Do not use the RNG seed as a unique run ID.
- Persist the final result and its progression credit through one coherent
  checkpoint transaction, reusing the current backup/recovery discipline. Avoid
  independent file writes that can save one half of the clear but lose the other.
- Derive setup availability from saved progression. Locked options explain the
  unlock requirement; incomplete content never appears as playable.
- Keep unlock/reward state independent of camera, pause and menu presentation.
  No camera completion event grants a championship or advances a season.

Required acceptance cases: a fresh profile; two Leagues with different progress;
a new League starting at Base; a championship and repeated restore of its result;
a loss with no tier unlock; corrupted-primary/valid-backup recovery; legacy run
continuation; and reset of temporary build power without loss of earned access.

The previously agreed implementation target remains a small complete slice:
finish game → reward → shop → buy/equip an authored effect → use it in the next
real game → save/reload. Full League content, higher-tier balancing and unusual
park mechanics remain later work. Prepare compatibility for approved rules;
do not prebuild every system in this packet.
