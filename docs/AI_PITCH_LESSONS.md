# Paid opponent pitch lessons

## Selected Working contract

This slice implements Economy v24's finite AI lesson row and purchase ordering,
Players/Pitches v17's exact recipe/learning contracts, and Current Decisions v31.
The complete current planning sources were read on 2026-10-03; Equipment/Sponsors
v18 was also checked. Their Working values remain Working. No new content or
balance approval is implied. The repository progression blueprint is unchanged.

New Working seasons select opponent policy5 before drafting. Market4 adds the
five Common ordinary lessons (OF, ON, SN, OS, SS) at their shared10-Cash prices to
six development cards across five families and13 initial passive Gear. Legal
shared roster targets filter lesson stock; affordability and profile preferences
do not. A full roster can see a lesson with a legal explicit replacement even
though this first AI purchase policy declines replacement. No Exotic/Rare lesson,
higher Gear unlock, human-unlock copying or forced preferred stock is enabled.

Ordinary supported parent weights are development25, lesson12, Gear20, renormalized
when empty. Development keeps its five equally weighted families with pitch
variants sharing one family; Gear keeps equal eligible slot weights. The ordinary
last-position repair supplies a second category where feasible. The fixed8-Cash
pack remains development-only, draws at most three distinct families, never both
pitch variants, and never refreshes on a reroll. This supported subset does not
claim identical exposure to the full human shop.

## Buying and personal growth

Existing legal objective/rotation purchases and qualified packs precede preferred
empty-slot Gear. Then Distributed and Pitching/defense clubs may purchase the
matching missing slider for their committed secondary pitcher: OS for natural
overhand delivery or SS for natural sidearm delivery. The first policy uses the
existing authored natural delivery for that preference; recipe resources retain
their own delivery, including mixed repertoires. Featured-hitter clubs skip lessons.
The role remains stable and an empty learned slot is required. There is no recipe
replacement, generic random lesson buying or inventory of unapplied lessons.

Every purchase uses the same atomic paid transaction as human learning. A newly
known exact recipe starts at1, or restores that player's own remembered level.
Mastery is never copied from another player; capacity never expands. A failed,
already-known or sold-stock purchase spends nothing. Decisions save exact item,
recipient, resulting recipe level, actual10-Cash cost and secondary-slider reason.

All purchases use one own-fixture18/12 W/L reward wallet. At most one ordinary
paid reroll is allowed only after no current affordable useful purchase remains,
and only when the post-reroll wallet can still afford a currently legal useful
objective, preferred empty-slot Gear or qualified secondary lesson at actual
price. No future stock or concealed pack peeking. Surviving clubs shop before
human checkout; no counter-shopping follows a human transaction.

## Runtime, UI and compatibility

Shared committed definitions supply the purchased recipe/own mastery to visible
and offscreen physical controllers. Authored natural resources remain unchanged.
Physical request hashes bind the complete repertoire and mastered definitions;
saved reports/replay must agree with the exact paid build at each fixture.
Ordinary per-game stamina handling is unchanged; this is not Doubleheader support.

Pregame exposes the actual secondary pitcher's full repertoire/levels/capacity,
selected policy rule or skip reason, and paid lesson history in the existing
wrapped clubhouse panel. Inspector/Bullpen continue showing those same committed
resources. Opponent panels are read-only. The centralized Equipped entry and
save-now/refund-now/live-effect-retire-next-batter contract remain unchanged.

Policy5/market4 is Build41/physical save49; Career21 remains unchanged. Save49
requires policy5 and physical evidence, selected before partial draft replay.
Policy4/market3/save48, policy3/market2/save47, physical policy1/2/save46 and
Build41 score-only/save45 remain frozen. Catalog signatures, receipt IDs,
prospective human unlocks and stock are not rewritten. Replay rejects substituted
policies/markets, journals, decisions and physical request/repertoire evidence.

Primary references: Godot [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)
and [ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html).
Godot caches loaded resources, so production uses the established copied committed
definitions and tests natural-resource isolation. The preparation panel uses the
existing wrapped containers/scrolling; native rendered review is recorded in
VERIFICATION and does not supply human visual/feel acceptance.

AI sponsors, learned abilities, tactical supplies, recruiting and Doubleheader
remain gated on their whole contracts. Permanent player ownership/packs, higher
Leagues/tiers, stadium progression, physical latency, final integration/full-suite
reliability and final cohesive UI/human visual/feel/hardware acceptance remain open.
