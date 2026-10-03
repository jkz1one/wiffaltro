# Paid opponent Gear market

## Contract and scope

New Working seasons select opponent policy3 before drafting. Market2 offers all
13 initial passive Gear items alongside the four legal stat-card families and
existing three-card stat pack. The implemented subset follows Economy v24,
Current Decisions v31 and Equipment/Sponsors v18, read from the current planning
sources on 2026-10-03. Working values and Proposal item labels retain their status.
No higher human unlock tiers are added to AI stock.

Development has ordinary category weight25 and Gear20, renormalized across these
two supported categories. Gear slots have equal eligible subweights; items are
uniform within the chosen slot. Four offers use the existing seeded visit RNG,
with last-offer category diversity repair when both categories remain eligible.
An exact currently equipped identity is excluded. Preferred stock is never forced.

Distributed clubs prefer Wide Barrel, Scraped Ball and Turf Shoes. Featured hitters
prefer Taped Bat, Batting Gloves and Slick Ball. Pitching/defense clubs prefer
Scraped Ball and Rosin Bag. Existing ranked development objectives take priority,
then an eligible paid stat pack, then the first affordable available preferred
Gear whose intended slot is empty. Every purchase uses the shared production
transaction and real paid receipt. No sidegrades, spare copies or resale-profit
policy are introduced.

One own-fixture reward wallet funds both development and Gear:18 Cash for a win,
12 for a loss. At most one ordinary paid reroll is allowed. It requires no current
affordable useful purchase and enough remaining Cash for at least one presently
legal useful card or preferred empty-slot Gear after the reroll. Future stock and
concealed pack contents are never inspected to make that choice.

## Runtime, replay and compatibility

Physical results settle before surviving opponents shop; human checkout cannot
trigger counter-shopping. Semifinal survivors shop before the final, eliminated
clubs do not. Shared team Gear reaches all four committed player definitions in
visible and offscreen matches. Existing passive modifiers and physical controllers
remain authoritative; no abstract strength or free growth substitutes for them.
Gear identities are included in physical request binding. Deterministic replay
rebuilds offers, purchases, wallets, receipts and decisions from the saved prefix.

Policy3 uses Build41, market2 and physical save47. Career21 is unchanged. Explicit
numeric version comparisons accept JSON's numeric representation. Physical policy1/2
saves remain46; historical Build41 score-only saves remain45. Old market1 and its
frozen signatures/receipt IDs remain unchanged. New policy3 cannot settle through
the score-only resolver. Its save requires the physical archive and exact policy
mapping; switching policy, market, receipt prefix or save version is rejected.
Human unlock state is not copied to AI, and access does not regenerate existing
stock. Human Equipped position and immediate live-sale ownership/refund with
next-batter effect retirement remain unchanged.

## Disclosure and review

Pregame shows committed opponent team slots, neutral/empty defaults, actual paid
prices, current item status and shared catalog effect text. Existing player-card
panels and wrapped labels provide the same visual hierarchy as the rest of the
shop/inspection UI. Opponent slots are read-only. The UI states the supported
finite pool and remaining gated categories.

Primary layout references: Godot [Container](https://docs.godotengine.org/en/stable/classes/class_container.html)
and [ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html).
Container-managed panels use existing theme spacing; scrollable preparation keeps
long effect disclosure accessible within the shared menu. Actual native capture
review and verification scope are recorded in VERIFICATION. Automated rendered
review does not provide human visual/feel acceptance.

Sponsors, lessons, abilities, tactical supplies, recruiting, mastery purchasing and
Doubleheader behavior remain gated until their full visible/offscreen contracts
are implemented. Physical round latency, permanent player-card ownership/packs,
higher Leagues/tiers, stadium progression and final whole-game acceptance remain open.
