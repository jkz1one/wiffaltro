# Materialized current-season gameplay integration

Status: checkpoint71 remotely verified at `9d532c44ace3c2df14861d6d2cd75d2f9076dccc`.
Checkpoint72 performance correction is documented in
[SUCCESSOR_MATERIALIZED_PERFORMANCE.md](SUCCESSOR_MATERIALIZED_PERFORMANCE.md).

This additive route follows verified checkpoint70. The draft-only reader and
its save slot remain unchanged. The new119 contract uses the separate
`wiffaltro-materialized-play-v1.json` slot, with explicit pristine70 import and
new-career creation. Original art, authored player profiles and gameplay rules
remain the source of behavior. This is not a replacement economy or final build.

## Intended boundary

Current human and five AI builds, current-season journals, pending physical
round evidence and the current career row are materialized directly. Cold
hydration is intended not to replay physical games or shop commands. Checkpoint72
profiling found that checkpoint71 still indirectly replayed the current Build
and development journal while deriving career progress, plus wallet commands
for sponsor counts. The earlier decoder/physics counters did not cover those
nested calls. Checkpoint72 replaces that summary path; see the linked evidence.
This is bounded offline consistency, not cryptographic anti-cheat provenance.

Actual matches and NPC fixtures keep the existing physics/report algorithms.
Explicit new-route adapters are necessary because frozen114 guards require a
standalone runtime without career/access state. Those original guards are not
weakened, and a career is not cleared to masquerade as standalone.

The intended qualification is genuine fresh draft, actual human game, two NPC
games, once-only round settlement, an earned paid pack and choice, then cold
reopen. Retained-candidate retries, changed-primary refusal, duplicate commands,
malformed saves and original-slot preservation must be checked as relevant.
No controls or lifecycle are considered working until verified.

## Deferred full integration

Season-terminal state must remain saveable, but permanent awards and career
advancement are not enabled in this increment. Dynasty needs explicit carried
human/AI factories and match-context validators: inherited114 rejects carried
AI profiles and matches with carried profiles on both sides. Alternate-league
pause/resume needs an atomic outer owner selecting independent current sessions,
not recursive prior-season envelopes. Replacement economics remain unresolved;
no fee or entitlement rule is invented here.

## Verification

The Standard one-round gameplay/shop/cold sequence, native smoke and final
exact-source review below have passed. No full-season, performance, Dynasty or
distributable pass is claimed.

Early diagnostics retained before physical play: the first fresh save was
refused by an exact JSON/native floating-point comparison at authored random
tie-break draws. The correction canonicalizes the detached, strictly validated primitive save
payload through JSON; this also handles physical evidence floats. Live RNG
values and exact monetary/statistical comparisons remain unchanged. A subsequent fourth-pick admission exposed omitted existing team strength, AI
`primary` pitch and authored opponent draft-order metadata fields. These are integration findings, not passes;
all prior durable draft boundaries were preserved for targeted retesting.

Actual gameplay subsequently produced one human and two NPC matches, each
preserved as durable pending evidence before settlement. An AI development
journal used an inert Godot StringName key (`replace`): the outer save primitive
gate was aligned with the inner build codec, retaining canonical-key collision
and Object rejection. Settlement then saved all three results once. A separate
earned cold load exposed a nested game-roster Array[String] hydration requirement;
the new build codec restores that type explicitly. No physical games were rerun
to diagnose or correct these serialization issues. The corrected earned shop/cold qualification is recorded below.


### Qualified Standard first-round path

The actual new119 launcher created a genuine first-run career, with four draft
choices and no injected predecessor. After the diagnosed admission fixes, the
saved third choice resumed to the fourth without replaying earlier choices.
The retained raw source and every ensuing operation have paired private evidence.

- Separate-process reopen of the drafted state: 1,703ms.
- Actual player-club match opened through App.play_next, ran original Pitch/Bat
  Lab physics with test automation, reached its completed-game outro, and saved
  a pending round before closing the lab. This is not a manual-input playtest.
- Two genuine NPC physical matches each saved their reports before settlement.
  First-NPC prewrite obstruction retained the exact report/candidate; retry
  committed once. Foreign, late and duplicate callbacks were inert.
- Round settlement saved one human and three total results once. Repeating
  settlement/retry neither repaid rewards nor rotated backup files.
- The original Shop displayed a real earned pack quote. Cancel, hidden player
  and sealed-card-order mutation rejection, prewrite refusal, exact retry and
  duplicate-command refusal passed. Purchase charged once.
- Actual generated card and recipient controls produced a choice that changed
  the selected player without charging again. Detached reference parity passed.
- A separate final earned reopen passed in 4,734ms. The main and backup bytes,
  purchased choice, six clubs' typed game rosters and once-only rewards survived.

Across each instrumented App.reload_save boundary, the old117 decoder, physical
resolver and current-round projector were not invoked. The final test also audits
bank journals against detached command references after loading; that audit is
not part of the cold reader and is not historical physical-game replay.

Observed full handlers remain slow: fourth draft15,819ms, faulted paid-pack
confirmation26,461ms, successful choice44,069ms. This is explicitly not a
responsiveness pass. Next optimization should profile repeated materialized
validation and immutable catalog work without weakening private ownership,
exact-disk/candidate checks or cold hydration.

Explicit pristine70 import also passed through the App. Both original70 main
and backup remained byte-identical, duplicate import was inert, and119 hydration
matched the imported state. This is not migration of earlier earned117 careers.


A focused synthetic cleanup callback fault also passed: after a durable write,
owner mismatch prevented promotion; a replacement lab prevented retry without
closing or writing; restoring the original owner promoted the already-durable
candidate without a second close/write. Duplicate promotion was inert. The
initial synthetic attempt accidentally set the existing difficulty value and
therefore triggered no mutation; that harness failure log was preserved and
corrected. This probe does not substitute for native pause/quit interaction.


Dugout also passed genuine fresh creation, all four picks, failed-write retry,
changed-primary refusal and separate cold reopen on119. Genuine earlier66 v3
main and backup operands remained unchanged. Observed milliseconds: birth4,919;
picks7,916/5,701(fault)/8,759/11,060; cold1,205. This is draft/save/cold
qualification, not a separate actual Dugout round or Dynasty proof.

Final pre-audit additionally found a post-close callback could install a
replacement lab before promotion. The App now records the successfully closed
boundary, refuses promotion while any replacement lab exists, and retains the
already-durable candidate. The expanded synthetic synchronous replacement probe
passed: replacement untouched, removal followed by exact promotion without
another close/write. Original physics and gameplay algorithms were unchanged.


### Native visual smoke

An isolated QA71 copy used the final guarded App and the genuine earned0009
snapshot. This was an earned-state visual test, not a second fresh-genesis test.
Native Continue showed Round2 Regular, Comets at Yard Club, standings, the
Yard Club at Switches4–5 result and authored roster/pitch/stat summaries. SHOP
showed4 Cash, Visit1 and Development pack: Used. PLAY opened the actual3D match.
Pause → Leave → Cancel retained it; Leave → OK returned to the season menu.
After closing safely from that menu, the copied save remained byte-identical:
SHA256 `72e26e0cbf762162a1e78f9ef3fccdff396dfe816ba9fb677434c92f3350fc56`.

The environment fell back to OpenGL llvmpipe and dummy audio. Historical
`src/tests` missing-fixture parse errors remain in the broad editor assembly.
This is not a clean release export, target-device performance/audio acceptance,
native full-match settlement, or OS-quit-during-match qualification.
