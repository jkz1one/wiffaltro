# Wiffaltro continuation checkpoint

Updated 2026-09-30 after publishing the recovered work and adding sponsor transaction foundations.

## Resume here

- Repository: `jkz1one/wiffaltro`.
- Active branch: `rebuild/season-engineering`. Continue this branch; do not restart from main.
- This checkpoint follows committed Special Order, Raincheck and Transfer Station work and
  completes Second Chance Supply, Late Checkout Motel and a tested atomic sponsor-set primitive.
  Use `git log -5 --oneline` for exact SHAs.
- Latest verified main at recovery: `f1dc209b6de11e45aedbd1568fa1b2d841dd2420`, already an ancestor.
- Read the newest entries in `SOURCE_OF_TRUTH.md`, `TECHNICAL_PREPRODUCTION.md`,
  `IMPLEMENTATION_STATUS.md` and `VERIFICATION.md` before choosing the next bounded slice.
- `PROGRESSION_BLUEPRINT.md` remains the preserved planning baseline. Newer source amendments
  and explicit Approved/Working/Proposal distinctions still apply.

Current planning source references, read again on 2026-09-30; resolve current versions before
implementing another contract. These IDs identify files, not permission to restore old versions.

| Source | Persistent file ID | Last read version |
| --- | --- | --- |
| WIFFALTRO_CURRENT_DECISIONS.md | `libfile_875a5513d66481919b39bbdf0002f202` | 31 |
| WIFFALTRO_EQUIPMENT_SPONSORS.md | `libfile_f4b3af37c2d88191bd4ceb24815411a8` | 18 |
| PROGRESSION_BLUEPRINT.md, retained contract annexes | `libfile_24485121f37081918000116b39146009` | 114 |

## Latest slice and publication

The user explicitly authorized "yes push and continue" on 2026-09-30. Second Chance and
Late Checkout were published through the connected GitHub API after CLI push failed for
missing credentials. Remote commits `ecd18a7` and `7c95104` have exact trees matching the
original local `6c3ecd0` and `f5a1b31`. Local checkpoint branch
`checkpoint/continuation-before-api-publish` preserves those originals. No merge or deployment.
This authorization covers continued engineering-branch pushes; do not ask again.

`SeasonSponsorSet` now supports an internal atomic group of explicit sponsor sales and up to
two purchases. Final sponsor/held capacity, optional peer-rarity restrictions, money, exact
paid refunds and receipt identity are validated before publishing. Synthetic tests cover the
capacity transitions needed by Neighborhood Association. This is an engine foundation:
J05 is NOT in the catalog, has no unlock/UI/live-sale integration and is NOT counted complete.
Build27/schema31/career8 and all existing shop/Wholesale behavior remain unchanged.

## Next slice: Neighborhood Association (J05)

The current source was reread this turn: Equipment/Sponsors v18 access lines 291–314 and
capacity lines 469–508, and retained Blueprint v114 J05 lines 5268–5292. Keep this Working
contract and Approved active-only ownership distinct:

- Uncommon, 14 Cash; earn permanent paid-shop access by confirming five distinct Common
  sponsors simultaneously active in a legal saved loadout. No win or ownership of J05 needed.
- Add two sponsor slots including J05 itself: current base five becomes seven total, with
  every other active sponsor Common. No free copies or rarity reclassification.
- Selling/replacing J05 must explicitly select any extra sales needed to make the entire
  final loadout legal. Never silently discard, reserve or disable excess sponsors.
- The new bank primitive must be connected through season transactions with derived prices
  and discounts. Add explicit selection/review UI for shop, Wholesale and live sales.
  Whole candidate/save rollback and next-batter effect retirement must apply to every sale.
- Add prospective career/save migration and paid generated-offer, UI interaction, reload,
  failed-save and live-game verification. Keep old displayed stock intact.
- Future League base-six capacity would become eight; do not claim that unimplemented
  League behavior. Small Batch and Double Major also remain unimplemented.

Late Checkout remains complete: paid earned access from a completed supplied walk and one
optional next-batter Tape/Plan inheritance, with exact receipt/swing provenance, no extra
consumption/chains, expiry/sale boundaries, explicit choices and old-save compatibility.

## Recovered prior slice

Second Chance Supply earns permanent paid-shop eligibility after three tactical consumptions
in completed games. Its purchased seasonal copy insures one explicitly selected eligible copy
before the game. A valid completed-use claim restores one fresh copy after the game if space
remains. Selection, skip, restart locking, sale timing, save retry and older-save migration are
implemented, together with pregame, Equipped, postgame and career-progress UI.

The same slice preserves Double Booking's completed-use evidence when its sponsor is sold
during the current game. Starting a new attempt replaces that evidence.

## User requirements to carry forward

- Continue in substantial, verified chunks and report the whole-project completion estimate
  at the end of each response. The recorded estimate is approximately **72%**, not release readiness.
- Preserve work with commits and pushes on the engineering branch. Do not merge or deploy.
- Preserve earlier gameplay/camera fixes and saved-run compatibility.
- Keep one clear Equipped lightbox accessible from the same button position during and between
  games. Gear and sponsors may be sold during play; save ownership/refunds immediately and
  retain active effects until the safe next-batter boundary.
- Include UI interaction and layout checks. Automated geometry is not native visual approval.
- The final implementation slice must be a cohesive high-end UI pass informed by primary
  references, with actual rendered review and human visual/feel acceptance.
- Do not promote Working values or unapproved Proposals to Approved. Ask at most three
  genuinely blocking design questions at once.

## Remaining scope

There are 26 of 35 supported sponsor candidates, 23 of 25 Gear candidates and all five initial
tactical supplies. Nine earned sponsor contracts, further AI acquisition, player-card contracts,
higher League/tier gameplay, stadium progression and final integration/acceptance remain open.
Recover the relevant current source contract before implementing a remaining candidate; the
counts alone are not a specification. Do not infer completion from older historical checklist entries.

The recorded native-display limitation and earlier unexplained full-suite early exit remain
open unless separately reproduced and resolved. Consult `VERIFICATION.md` for the exact fresh
test scope and distinguish it from historical combined coverage.
