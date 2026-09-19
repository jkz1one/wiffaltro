# Plastic-Ball Baseball Roguelite — Source of Truth

**Version:** v0.4.3  
**Status:** FROZEN PRE-REPO BASELINE  
**Supersedes:** v0.4.2 and all earlier planning notes  
**Change rule:** Do not reopen frozen decisions unless implementation, playtesting, research, or a clear design contradiction gives us a concrete reason.

---

## 1. Executive Summary

### One-line concept

A fast arcade plastic-ball baseball roguelite where **one run equals one season**, every pitch and swing is player-controlled, and temporary team builds combine with a persistent evolving club and home stadium.

### Short pitch

You build a tiny four-player plastic-ball team through new Pitches, Hitting Abilities, Fielding Abilities, Gear, Endorsements, and limited seasonal development while competing through a real 10-game league and playoffs. Pitching and hitting are skill-driven, while defense is streamlined through one strategically positioned automated fielder, automatic pitcher defense, and ghost runners. Opponents develop alongside you, fields become increasingly strange, and every season produces a different build. When the season ends, temporary team power resets, but your club identity, records, unlocks, and home stadium persist.

### Reference shorthand

**Backyard Baseball × Balatro**, with deep plastic-ball pitching, physical ballparks, small two-way rosters, real standings, and a persistent stadium career layer.

This is shorthand only. The game does **not** map Balatro systems one-to-one.

---

## 2. Design Pillars

### Pitching is a headline mechanic

Pitch repertoires, delivery slots, sequencing, stamina, execution, and plastic-ball movement must be deep enough to support builds by themselves.

### Physical fields are rules

Park geometry is not scenery. It affects hit outcomes, defense, positioning, rebounds, and strategy.

### Small roster, strong identity

Four active two-way players means every roster decision matters.

### Build resets, club persists

Seasonal power is disposable. Club identity, history, unlocks, and stadium progression provide the long-term attachment.

### Readable absurdity

Early seasons teach understandable baseball. Later Leagues, Pitches, Endorsements, and fields can become increasingly strange without losing mechanical clarity.

---

## 3. Core Progression Loop

### Preseason

Choose **League + Difficulty** → receive/select a four-player roster → configure persistent home stadium → set batting order and loadouts.

### Regular season

Play game → earn Season Cash and Hype → postgame shop → improve players/build → opponents evolve → standings update → limited Free Agent decisions → trade deadline → final roster/build push.

### Postseason

Top four qualify → higher-seed semifinal → neutral-site championship.

### Season end

Temporary build resets → career history is recorded → Club Funds are awarded → unlocks progress → jerseys/emblems/stadium can be improved → begin another season.

---

# 4. Baseball Rules

## Roster

**4 active two-way players.**

Every player can hit, pitch, and field, but has distinct strengths.

No bench in the baseline game.

## Player stats

- Contact
- Power
- Fielding
- Velocity
- Break
- Control
- Stamina

No Speed, Arm, or Discipline stat in v1 unless prototype evidence creates a clear need.

Handedness, natural delivery, repertoire, repertoire capacity, and similar identity elements are properties rather than stats.

## Game length

- 5 innings
- 3 outs per half inning
- 4 balls
- 3 strikes
- Two-strike fouls remain at two strikes
- 10-run mercy rule after 3 completed innings
- Extra innings begin with a ghost runner on second

Five innings and the mercy threshold remain subject to real match-length testing, but they are the prototype baseline.

## Batting order

Fixed before the game and cycles normally.

---

# 5. Ghost Runner / Base System

No physical baserunners in v1.

Bases exist as a simulated state.

Baseline advancement:

- Single: batter to first; existing runners advance one base
- Double: batter to second; existing runners advance two bases
- Triple: batter to third; existing runners score
- Home Run: all runners score
- Walk: forced advancement only
- Ordinary out: runners hold unless a tag/sacrifice rule applies

No:

- manual baserunning
- stealing
- leads
- pickoffs
- rundowns/pickles

## Sacrifice flies

Ghost runners can tag without visible runners.

Advancement is determined by the physical defensive situation, primarily:

- catch location/depth
- defensive return time
- fielder ability
- standardized ghost-runner advancement time

A shallow catch may allow no advancement. A deep catch may allow a runner from third to score. Extremely deep/awkward catches may allow other runners to advance.

No dedicated runner Speed stat is required initially.

---

# 6. Hitting

## Controls

Hybrid arcade aiming + timing.

The player:

1. aims a forgiving contact region
2. chooses **Contact Swing** or **Power Swing**
3. commits to the swing

## Contact Swing

- larger spatial/timing forgiveness
- lower maximum exit-velocity ceiling

## Power Swing

- smaller spatial/timing forgiveness
- higher exit-velocity ceiling

## Direction

Timing influences spray:

- early → pull
- centered → center
- late → opposite field

Vertical bat/ball relationship influences:

- grounder
- line drive
- fly ball
- launch angle
- backspin tendency

Stats and modifiers should amplify user execution rather than replace it.

---

# 7. Pitching

## Core loop

Choose **Pitch → target location → effort/execution → release**.

No steering after release.

## Pitch terminology

For game-facing terminology, a **Pitch** already includes its delivery/arm slot.

Therefore:

- Overhand Sinker
- Sidearm Sinker
- Submarine Sinker

are three different Pitches.

Internally, code may use `PitchDefinition`, but player-facing documents should simply say **Pitch**.

## Standard deliveries

- Overhand
- Three-Quarter
- Sidearm
- Submarine

Underhand or stranger deliveries may appear later.

Every player has a **Natural Delivery**.

Alternate deliveries are allowed but normally incur soft penalties such as:

- worse Control
- greater execution difficulty
- less movement consistency
- higher Stamina cost

Traits, Gear, Endorsements, or other effects may reduce, remove, or reverse those penalties.

## Pitch categories

### Fastballs

Velocity/power-oriented.

Examples:

- Four-Seam Fastball
- Two-Seam Fastball
- Sinker
- Cutter

### Breaking Balls

Movement/shape-oriented.

Examples:

- Slider
- Sweeper
- Curveball
- Slurve

### Off-Speed

Timing/deception-oriented.

Examples:

- Changeup
- Splitter
- Forkball
- Screwball

### Unconventional

Extreme trajectory, instability, or timing disruption.

Examples:

- Eephus
- Knuckleball
- Knuckle-Curve
- increasingly fictional Pitches

## Pitch design law

Every named Pitch must answer:

**Why would I throw this instead of another Pitch?**

A Pitch should not exist only as a minor numerical variant.

Identity can come from:

- velocity
- release point
- break direction
- break timing
- arc
- deception
- instability
- stamina efficiency
- Control demands
- risk/reward

---

# 8. Pitch Physics

Pitch names are tactical identities, not hardcoded canned curves.

Pitch flight may depend on:

- initial velocity
- release point
- spin rate
- effective/true spin
- spin axis
- ball orientation
- perforation/hole orientation
- ball condition/surface profile
- drag
- lift
- stability
- wind
- delivery geometry

Important physics principle:

**Movement magnitude and movement direction are separate concepts.**

Higher spin does not automatically mean “more Break.” Effective spin, spin axis, velocity, release, orientation, and plastic-ball asymmetry combine to determine flight.

Plastic-ball behavior may deliberately exaggerate familiar baseball pitch shapes.

## Knuckleball

Not implemented as arbitrary random zig-zagging.

Low spin and unstable orientation should cause changing aerodynamic forces. Any deterministic wobble/noise should be seeded for reproducibility.

## Eephus

Handled by the same flight model using very low initial velocity and a high arc rather than by a special fake trajectory.

---

# 9. Repertoire

Approximate repertoire capacities:

- poor pitcher: ~2 Pitches
- normal pitcher: ~3
- good pitcher: ~4
- elite pitcher: ~5–6
- rare/special pitcher or modifiers: potentially 6–8+

All known Pitches are normally available every pitch.

Modifiers may temporarily alter availability.

There is no generic default “Straight” pitch.

## Learning Pitches

Pitches can be acquired during a season.

If the player is at capacity, learning a new Pitch requires forgetting one.

Season-learned Pitches reset at season end.

Permanent progression unlocks Pitches into future availability pools rather than permanently teaching them to a character.

---

# 10. Stamina and Pitching Changes

Pitchers may remain in at **0 Stamina**.

Low/zero Stamina creates increasing risk through:

- Control deterioration
- reduced velocity
- less consistent movement
- execution failures
- hangers

A hanger should preferably emerge from degraded execution/movement rather than a scripted “throw center” rule.

Pitching changes:

- only between batters
- removed pitchers may re-enter later
- Stamina remains where it was
- no default passive regeneration

---

# 11. Defense

## Defensive assignments

At the beginning of a defensive half-inning, the team has:

- one active Pitcher
- one active Primary Fielder

The Primary Fielder must be one of the other three players.

The remaining two players are inactive defensively at that moment.

## Between batters

The player may change:

- Pitcher
- Primary Fielder

Selections persist until changed.

If the current fielder becomes the Pitcher, another player must be selected as the Primary Fielder.

## Before each pitch

The Primary Fielder can be positioned in a persistent 3×3 grid:

| Depth | Left | Center | Right |
|---|---|---|---|
| Shallow | Shallow Left | Shallow Center | Shallow Right |
| Middle | Middle Left | Middle Center | Middle Right |
| Deep | Deep Left | Deep Center | Deep Right |

Position persists until changed.

Position locks once the pitching motion begins.

## Pitcher defense

The Pitcher automatically participates on:

- comeback liners
- weak grounders
- close mound-area plays
- possible hard deflections

The Pitcher does not roam as the Primary Fielder.

## Fielding outcomes

Base defense should be deterministic/readable rather than built primarily on hidden random percentages.

Possible outcomes:

- clean field/catch
- bobble
- deflection
- miss

Fielding difficulty can consider:

- ball speed
- trajectory
- reach
- arrival timing
- bounce complexity
- Fielding stat
- applicable Fielding Ability

---

# 12. Ball-in-Play / Hit Resolution

Governing principle:

**Defense determines whether the ball is stopped. The field determines what an unstopped ball is worth.**

Baseline starter-field rules:

- caught fly → Out
- ground ball cleanly controlled before safe territory → Out
- fair ball beating defense into ordinary safe territory → Single
- untouched deep airborne ball → Double
- ground/bouncing ball reaching back wall/fence → Double
- back wall/fence struck on the fly → Triple
- HR boundary cleared on the fly → Home Run

Individual parks and ground-rule objects may override baseline rules.

## Bobbles

Bobbles/deflections keep the play live.

A bobbled fair ball normally establishes at least a Single, while recovery may prevent further advancement.

---

# 13. Field Object Architecture

Field objects fall into three gameplay categories.

## Live Object

Physical collision; ball remains live.

Examples:

- wall
- tree
- chair
- pole

## Dead Ground Rule

Collision immediately resolves an authored result.

Examples:

- pool = Double
- special window = Home Run

## Physics Modifier

Changes the ball but keeps play live.

Examples:

- ramp
- trampoline
- fan
- mud
- special bounce surface

This architecture must support absurd later fields without rewriting core ball-play rules.

---

# 14. Season Structure

## League size

6 teams total:

- player club
- 5 AI clubs

## Schedule

Double round robin:

- each opponent once home
- each opponent once away
- 10 regular-season games

Other AI-vs-AI games are resolved through lightweight simulation, producing real standings.

## Playoffs

Top 4 qualify.

- Semifinal: single elimination, higher seed hosts
- Championship: single elimination, special neutral field

Exact tiebreaker details remain deferred.

---

# 15. Opponents

Opponent clubs have authored strategic identities rather than random stat soup.

They visibly develop over the season through:

- better/expanded Pitch repertoires
- traits
- Gear
- Endorsements
- field identity
- strategic behavior

Rematches should feel like evolved versions of the same opponent.

Difficulty escalation follows calendar/opponent development rather than rubber-banding against the player's record.

AI must not read hidden player input.

---

# 16. League and Difficulty

## League

League is the **Balatro Deck analogue**.

Chosen before the season.

Its structural rule persists for the run.

Early Leagues are simple. Later Leagues may radically alter:

- roster construction
- pitching rules
- Stamina
- economy
- shop structure
- field behavior
- modifier availability
- season rules

A League can eventually introduce rules such as starting with only three players and an open roster slot.

That is **not** the base game.

## Difficulty

Difficulty is separate from League.

Progression is tracked independently for each League.

Higher Difficulty may increase:

- economy pressure
- opponent development
- roster constraints
- shop pressure
- AI tactical quality
- recovery pressure
- special conditions

Avoid relying on invisible stat inflation as the primary difficulty mechanism.

---

# 17. Player Abilities

Seasonal player development is broader than Pitches.

## Hitting Abilities

Player-specific seasonal effects that alter hitting strategy/execution.

Prototype target: **1 active Hitting Ability per player**.

Examples only:

- Two-Strike Approach
- Dead Red
- High-Ball Hitter
- Pull Happy
- Opposite Field
- First-Pitch Swinger
- Wall Hunter

## Fielding Abilities

Player-specific seasonal effects that alter defensive behavior.

Prototype target: **1 active Fielding Ability per player**.

Examples only:

- Quick First Step
- Soft Hands
- Wall Rat
- Line-Drive Reader
- Barehander
- No Fear

Fielding Abilities may apply to Pitcher defense when appropriate.

## Replacement

If a Hitting or Fielding Ability slot is already occupied, learning another replaces the current one.

Learned Hitting/Fielding Abilities reset at season end.

They are not normally sellable once learned.

## Intrinsic Trait

A player's intrinsic trait is separate from seasonal Abilities and is part of the character's base identity.

---

# 18. Seasonal Build

Short form:

**Roster + Abilities + Pitches + Gear + Endorsements**

Where:

- **Abilities** = Hitting Abilities + Fielding Abilities
- **Pitches** = repertoire items, each already including its arm slot
- **Gear** = physical equipment
- **Endorsements** = team-wide seasonal engine pieces

---

# 19. Gear

Initial Gear scope is deliberately small.

## Bat

Each player equips one active Bat.

Potential effects can touch:

- Contact forgiveness
- Power
- launch tendencies
- contact-type interactions
- Hype
- special triggers

## Ball Setup / Ball Prep

The team has one active Ball Setup by default.

It may alter:

- Break
- stability
- Control
- Velocity
- Pitch-family behavior
- plastic-ball aerodynamic behavior

Effects may later allow carrying or switching multiple ball setups.

## Inventory baseline

Prototype recommendation:

- one active Bat per player
- one active team Ball Setup
- small reserve Gear inventory
- free pregame configuration
- Gear normally locks once the first pitch is thrown
- special effects may allow midgame swaps

Gear is sellable.

---

# 20. Endorsements

Endorsements are the closest Joker-like engine system.

They are:

- team-wide
- season-local
- passive/rule/economy/build effects
- sellable/replaceable
- limited-slot

Prototype target: **around 5 active Endorsement slots**.

Exact slot count remains a tuning variable, not a sacred number.

Endorsements may be themed as absurd sponsors, from tiny local businesses to increasingly major brands.

Not all Endorsements should be money effects.

---

# 21. Shop

The first shop appears after Game 1.

A shop appears after every regular-season game.

Core offer categories:

- Gear
- Abilities
- Pitches
- Endorsements

Player-facing presentation may group Hitting/Fielding Abilities together while keeping Pitches distinct.

Free Agents appear occasionally as a special roster opportunity before the trade deadline.

Prototype target: roughly 5 normal mixed offers.

Generation should have diversity protection so obviously useless all-one-category shops are uncommon unless intentionally caused by a modifier.

## Rerolls

Paid with Season Cash.

Reroll cost escalates during the current shop visit and resets at the next shop.

## Selling

- Gear: sellable
- Endorsements: sellable
- learned Hitting/Fielding Abilities: not normally sellable
- learned Pitches: not sellable

Approximate starting sell-value target: ~50% purchase price, subject to economy simulation.

---

# 22. Rarity

Initial rarity vocabulary:

- Common
- Uncommon
- Rare
- Exotic

Anything may theoretically appear early.

High-rarity odds improve mildly later in the season.

Anti-drought protection may prevent an entire 10-game season from never surfacing interesting high-rarity content.

Rarity should primarily represent:

- specialization
- strangeness
- build-defining potential
- rule-breaking capability

not simply larger numbers.

---

# 23. Free Agents

Free Agents appear occasionally before the roster deadline.

Signing one immediately replaces one of the four active players.

No bench in the baseline.

The departing player takes with them:

- seasonal stat development
- learned Hitting Ability
- learned Fielding Ability
- learned Pitches

Equipped Gear returns to the team inventory rather than disappearing.

## Trade deadline

Current recommendation: **after Game 6**.

The Game 6 postgame shop is the final roster-change opportunity.

After leaving it, roster locks for Games 7–10 and playoffs.

Exact Free Agent appearance frequency remains a simulation/tuning decision.

---

# 24. Roster Construction

Baseline recommendation:

**Four-round tryout draft.**

Each round:

- 3 player cards appear
- choose 1
- repeat four times

This exposes 12 candidates and produces 4 selected players without forcing a giant preseason roster screen.

Soft protections may prevent completely dysfunctional offer sets, but there are no conventional fielding positions because all players are two-way.

This remains a strong baseline but can be adjusted after prototype testing without changing core architecture.

---

# 25. Player Definitions

A player definition includes at least:

- Name/visual identity
- Handedness
- Contact
- Power
- Fielding
- Velocity
- Break
- Control
- Stamina
- Natural Delivery
- Pitch capacity
- Starting Pitches
- Intrinsic Trait

Players should be **authored named characters**, not anonymous procedural stat bundles.

Quality should emphasize specialization and tradeoffs rather than a strict universal hierarchy.

---

# 26. Seasonal Player Development

Player development should remain lighter than a traditional sports RPG.

Current prototype recommendation:

Three development breaks across the regular season, roughly after Games 3, 6, and 9.

Possible simple upgrades:

- +1 Contact
- +1 Power
- +1 Fielding
- +1 Velocity
- +1 Break
- +1 Control
- +1 Stamina

Rarer development may alter:

- Pitch capacity
- alternate-delivery penalty
- fatigue tolerance

All seasonal stat development resets after the season.

Exact cadence is not locked until the economy/run simulation is tested.

---

# 27. Season Cash

Temporary run currency.

Resets every season.

Used for:

- Gear
- Abilities
- Pitches
- Endorsements
- Free Agents
- rerolls

Winning pays substantially more than losing.

A loss still pays something.

Hype adds bonus income, but a great loss should not normally be economically equivalent to a win.

Exact numbers and price bands remain explicitly deferred to simulation.

---

# 28. Hype

Working name for the secondary performance system.

Runs remain the only score that determines who wins.

Hype can reward:

- perfect contact
- Home Runs
- extra-base hits
- unusual field interactions
- strikeouts
- called strikeouts
- three-pitch strikeouts
- escaping jams
- walkoffs
- modifier chains

Hype contributes to Season Cash payout.

Score Attack may later reuse Hype as the primary score.

The name **Hype** remains provisional.

---

# 29. Persistent Progression

Design law:

**Your club persists. Your build resets.**

## Persistent

- club name/identity
- jerseys/uniforms
- emblem/branding
- home stadium
- owned stadium pieces
- career records/history
- trophies/accomplishments- League × Difficulty clears
- unlock pools
- cosmetics

Potentially named-player career statistical history may persist as history only, not power.

## Resets every season

- roster composition
- seasonal stat upgrades
- learned Hitting Abilities
- learned Fielding Abilities
- learned Pitches
- Gear
- active Endorsements
- Season Cash
- Stamina/fatigue
- shop state
- temporary synergies/conditions

---

# 30. Club Funds

Persistent currency.

Primarily awarded at season end.

Potential payout factors:

- season completion
- record
- playoff finish
- championship
- Difficulty
- first League × Difficulty clear
- career achievements
- major records/accomplishments

Club Funds buy persistent club/stadium ownership such as:

- stadium parts
- venue infrastructure
- uniforms
- emblems
- branding
- cosmetics

Avoid using Club Funds to buy permanent universal stat power.

Preferred model:

**unlock + purchase**

Progression unlocks a permanent item into the available catalog.

Club Funds purchase ownership.

Once owned, remodeling among owned pieces is generally free between seasons.

---

# 31. Home Stadium

The Home Stadium is the player's persistent career avatar.

Progression fantasy:

backyard  
→ organized yard  
→ neighborhood field  
→ town venue  
→ regional plastic-ball park  
→ sophisticated miniature stadium

Potential additions:

- baselines
- backstop
- fencing
- foul poles
- benches
- bleachers
- manual scoreboard
- lights
- concessions
- PA/scorer structures
- sponsor architecture
- custom landmarks
- surfaces

Geometry generally affects both teams symmetrically.

Strategic value comes from learning and building around the field, not permanent asymmetric power.

Structural remodeling occurs **between seasons**.

Opening Day locks structural configuration through the championship.

Temporary League/modifier conditions may still alter a field.

---

# 32. Secondary Modes

After Season Mode is proven:

## Score Attack

Short offense-focused score chase using Hype/physical-field interactions.

## Challenge Mode

Handcrafted scenarios and restrictions.

## Practice / Wiffle Lab

Pitching/batting experimentation and tuning.

---

# 33. Visual Direction

- stylized full-3D characters
- stylized physical 3D fields
- illustrated 2D portraits/cards/UI
- DIY neighborhood/rec-league aesthetic
- progressively more organized/absurd presentation

Avoid:

- realistic sports rendering
- direct Backyard Baseball imitation
- cheap generic mobile gloss

Audio should enter early:

- plastic bat thwack
- ball whoosh
- strike target impact
- fence/wall/material impacts

---

# 34. Technical Baseline

Godot is the production engine assumption unless implementation exposes a concrete blocker.

Baseline:

- Godot 4.7.2
- typed GDScript
- Mobile renderer
- Jolt for 3D collision/physical ball-in-play
- Blender → glTF/GLB
- Git/GitHub
- Steam/PC + iOS + Android as first-class architectural targets
- no multiplayer requirement in v1
- consoles deferred

Pitch flight uses a custom fixed-step aerodynamic solver rather than stock rigid-body flight.

Batted-ball play uses a hybrid of custom aerodynamic forces, Jolt collision, and authored baseball-rule resolution.

See `TECHNICAL_PREPRODUCTION.md`.

---

# 35. Prototype / Production Order

## Phase 0 — Foundation

Project structure, definitions, runtime state, content manifest, math conventions, debug scaffolding.

## Phase 1 — Pitch/Bat Lab

Pitch solver, aim, execution, strike zone, swing model, contact resolution.

## Phase 2 — Ball-in-Play Lab

Batted-ball physics, field rules, one fielder, pitcher defense, bobbles, ghost bases, sacrifice advancement.

## Phase 3 — Complete Vanilla Match

Four-player rosters, batting order, counts, Stamina, pitching changes, five innings, mercy, extra innings.

## Production Gate

The core sport must be fun before building the roguelite shell.

Only after that:

- shops
- abilities
- Pitches as economy content
- Gear
- Endorsements
- Free Agents
- micro-season
- full season
- League × Difficulty
- persistent stadium
- meta progression

---

# 36. Explicitly Deferred / Tunable

These are **not unresolved architecture blockers**:

- exact item prices
- exact Season Cash payouts
- exact rarity percentages
- exact Free Agent frequency
- final Endorsement slot count
- exact development-break cadence
- exact shop category weights
- final Hype name/formula
- exact five-inning/mercy balance after real timing tests
- final pitch coefficient values
- final stat ranges
- final number of authored launch-day players/Pitches/Endorsements

These are to be tuned through simulation and playtesting rather than debated abstractly.

---

# 37. Change-Control Rule

This document is the pre-repo gameplay source of truth.

When implementation reveals a conflict:

1. identify the concrete problem
2. test whether it is tuning, architecture, or design
3. prefer the smallest coherent change
4. update this document when the decision actually changes

Do not silently let code become a competing design document.