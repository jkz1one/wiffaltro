# Paid opponent batting supplies

Working implementation, 2026-10-04 UTC. New Working seasons use Build41,
save53, Career21, opponent policy9 and AI market8. Policy8/market7/save52
keeps its choice sponsors, supply-free stock, report2 and request hashes.
Policy7/market6/save51/report1 and all prior mappings remain frozen.

## Complete current contract and bounded scope

Read complete Current Decisions31, Economy24 (including its final358 lines),
Players/Pitches17 and Equipment/Sponsors18. Economy's finite AI buying/use
section supplies the featured-hitter targets, shared-wallet purchase order and
pre-first-pitch tactical readiness. Players supplies held ownership, one club
activation per PA, effect duration, shared prices/weights and fixed packs.
This slice enables only paid Grip Tape and Swing Plan. Recovery, Extra Heat,
Take a Base and Budget Bites remain gated on their complete fatigue, scoring,
grant and consumption contracts. No announcement or transformation is enabled.
Repository PROGRESSION_BLUEPRINT remains byte-identical to main.

Market8 adds a tactical category with the selected10 base weight to the prior
25 development /12 lessons /20 Gear /10 abilities /20 sponsors. Its supported
subset is Tape/Plan, ordinary weight1 each, therefore50/50 conditional on that
category before stock repair. This is reduced exposure, not the full five-type
human distribution. Existing category diversity repair and equal eligible Gear
slots remain. Wallet, profile, temporary readiness and bag occupancy do not
filter or force stock. Two copies of the same tactical type may be held. The
fixed8-Cash development pack stays family-distinct, development-only, unchanged
by rerolls and never includes both pitch variants.

Development/qualified packs, preferred empty-slot Gear, qualified sponsors and
role learning/secondary slider precede supplies. Buy actual displayed affordable
Tape first, otherwise Plan, into a free shared held slot, at3 Cash each. All
three profiles use the saved featured hitter. No role retarget, replacement,
disposal, free grant, hidden reserve or side wallet. Re-evaluate after purchases;
at most one useful affordable ordinary paid reroll can compete with acquisition.
Skipped packs remain spent. Surviving clubs shop before human checkout, including
semifinal survivors; human shopping never causes another AI checkout.

## Shared gameplay and evidence

New AI teams copy their exact paid bag and committed featured hitter into each
fresh match. At legal pre-first-pitch readiness, before recipe selection, use
Tape on that hitter, otherwise Plan. Plan chooses Power only when actual Power
exceeds Contact; ties choose Contact. One club activation per PA; repeated
preparation, fouls, canceled delivery and pitching substitutions cannot duplicate
or extend it. Other batters retain held copies. Human teams keep explicit actions,
even with two diagnostic controllers. No unreleased pitch, target, contact, RNG
or future result informs activation.

Shared MatchTactics applies Tape's coverage×1.08 and fair exit-speed×0.95, or
Plan's locked swing with×1.06 exit speed only at qualifying fair quality>=65%.
AI swing execution respects that same lock. No permanent stats, fabricated hit
or forced score. Existing choice-sponsor/Gear stacks and natural assets remain.
Ordinary HUD feedback names the consumed supply and Plan mode before play. It
uses the existing feedback position; centered Equipped stays unchanged.

Report3/resolver physical-ai-batting-supplies-v1 adds exact initial, consumed and
remaining copy evidence, featured hitter, Plan mode and completed batting sides.
Validation reconstructs the deterministic Tape-before-Plan consumption at each
actual featured PA. Missing, duplicate, extra, foreign, wrongly priced, late or
wrong-mode copies reject. Replay binds the initial paid bag and featured player
to the committed request. New request hashes include that bag/policy; old request
hashes/report1/report2 shapes remain unchanged. JSON round trips are checked.
Detached requests deep-copy inventories and cannot mutate caller ownership.

Managed results append opponent supply evidence as a prospective13th pending
argument. Historical pending jobs retain their12 arguments. The evidence is
required even for an empty bag, belongs only to the actual opponent, and binds
completed PAs/statistics and initial ownership. The original human evidence/outro
remains; no mid-match resume system is introduced. Original Continue publishes
round results atomically. Each opponent reward consumes its own exact paid copies
through shared SeasonTacticalPurchase settlement, once, before survivor shopping.
Rebuilds, forks, career saves and retries derive the same remaining bag/wallet.

## Presentation and remaining acceptance

Pregame shows the shared2-slot bag, actual paid copies/effects, target/mode and
complete purchase/use history. Other supplies and Budget Bites are disclosed as
gated. Panels use existing wrapped, themed, scrolling preparation UI. Immediate
human live-sale ownership/refunds with next-batter effect retirement remain intact.

Primary references consulted: Godot [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)
for cached-resource isolation/deep copy and [RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)
for test-only drawing control. Hidden native preparation/diagnostics may omit
drawing while complete fixed-step physics runs. VERIFICATION records actual
rendered scope and reviewed originals. Automation is not human visual/feel approval.

Working values remain Working. Higher Leagues/tiers, permanent players/packs,
stadiums, costly physical simulation, integration/full-suite reliability and final
cohesive whole-game UI/human visual/feel/hardware acceptance remain open.
