# Paid opponent learned abilities

## Selected Working contract

This slice implements the finite learned-ability row and named profile rules in
Economy24, Players/Pitches17 and Current Decisions31, with Equipment/Sponsors18's
capacity/removal constraints. Current sources were reread on2026-10-03. Working
prices and effects remain Working; implementation does not approve new tuning.
The repository progression blueprint stays byte-identical to main.

New Working seasons choose policy6 before drafting. Market5 adds Work the Count
(ability.A05, Uncommon12), Soft Hands (ability.A06, Common10) and Sky Reader
(ability.C01, Uncommon12) to six development cards,13 initial Gear and five Common
lessons. Shared legal learned targets govern stock. Published AI access includes
Sky independently of human career discovery; this does not grant human access,
free learning or any extra Fielding slot. Historical AI markets remain ability-free.

Ordinary supported category weights are development25/lesson12/Gear20/ability10,
renormalized when a pool is empty. Ability identity weights remain the shared
2/1/1 for Soft Hands/Work the Count/Sky Reader. Keep existing five development
families, equal Gear slots and last-position category repair. Wallet and profile
preferences never filter offers or force useful stock. Full-slot legal replacement
offers may appear even though this buying policy declines replacements.
With all four pools present, initial draw shares are25/67,12/67,20/67,10/67;
last-position repair can change the final mix. This subset does not claim identical
exposure to the complete human shop.
The fixed8-Cash pack stays development-only, with three distinct eligible families
and never both mastery variants. Ordinary rerolls never refresh the fixed pack.

## Buying and receipts

Existing ranked objective/rotation loose development and qualified packs come first,
then preferred empty-slot Gear, then learned abilities, then the prior secondary
slider lesson policy. No sponsor/tactical/recruit purchase is enabled.

- Distributed: Soft Hands on the committed primary fielder.
- Featured hitter: Work the Count on the committed featured hitter.
- Pitching/defense: Soft Hands on the primary fielder; otherwise available Sky Reader.

Sky is an alternative when Hands cannot be bought, not a second Fielding slot.
Once either occupies that role's slot, the policy skips further Fielding learning.
No forgetting, replacement, spare ability card, copied learning or free grant.
The actual shared ability_buy transaction charges10/12 and immediately assigns
one legal player-local seasonal receipt. Invalid/foreign/full/known/sold/unaffordable
transactions roll back atomically. Every AI decision records item,recipient,price,
game and request identity using the same own18/12 W/L reward wallet as other buys.

After each purchase, reevaluate real remaining offers, legal targets and money.
At most one paid ordinary reroll is allowed, only when no current useful purchase
remains and its remaining wallet can still buy a currently legal useful item at
actual price. No future-stock or concealed-pack peek. Paid skipped packs still
spend8. Surviving clubs shop before the human; human checkout cannot counter-shop.

## Physical effects and compatibility

Shared copied committed definitions carry learned IDs into managed and offscreen
physical matches. Work the Count requires two actually released, called balls
within that PA; it adds6% of source spatial X/Y radii once, without timing/exit
bonuses. Starting count, canceled pitches and fouls grant no progress; the next PA
resets it. Soft Hands adds0.10 only to eligible grounded clean control after normal
reach,height and reaction checks. Sky Reader scales the primary fielder's initial
reaction delay by0.60 on actual fair launches>=25degrees, respecting the shared
minimum and existing Goggles order; no speed/reach or premature movement benefit.
No new controller observations, artificial events or item-price strength proxy.

Existing physical request hashes bind the complete exported learned definitions.
Exact saved replay reconstructs journals,receipts,decisions,wallets and requests;
natural resources and forked builds remain isolated. Policy6/market5 uses Build41/
physical save50, with Career21 unchanged. Policy5/market4/save49, mastery4/3/save48,
Gear3/2/save47, physical1/2/save46 and score-only Build41/save45 stay frozen.
No old save is silently upgraded to new stock or new buying behavior. Catalog
signatures,receipt IDs,prospective human unlocks and deferred live-sale retirement
remain intact. SeasonBuild remains921 lines.

Pregame shows the exact committed role, occupied learned slot, preferred rules,
actual effect text and complete paid learning history in read-only shared panels.
Player inspection continues showing the same learned IDs in real match rosters.
The centered Equipped entry remains fixed between shop and games.

Primary references: Godot [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)
and [ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html).
The implementation retains existing copied resources and container layout; native
review waits for layout before scrolling newly rendered disclosure into view.
See VERIFICATION for actual checks and unedited images. Automated native review
never supplies human visual/feel acceptance.

AI sponsors,tactical supplies,recruiting and Doubleheader still need whole contracts.
Permanent player ownership/packs,higher Leagues/tiers,stadiums,physical latency,
final integration/full-suite reliability and cohesive final whole-game/human visual/
feel/hardware acceptance remain open. This is a targeted slice, not release readiness.
