# General ordinary App interruption safety

The additive Game114 staging App now owns a dedicated, connected unfinished-game
confirmation rather than relying on the unwired inherited dialog. Leave and
window-close requests share one fixed action path. Cancel preserves the match;
confirmation is pinned to the exact season, lab and match state and consumed
before cleanup. Repeated/conflicting requests cannot retarget it. Changes during
confirmation or cleanup cannot close a replacement owner.

The App disables automatic window close while mounted, and restores the prior
policy on teardown. Busy simulation/save work, a retained candidate/report/human
capture, or a completed unsaved game blocks exit. A durably saved pending round
may close safely. This cannot prevent OS/process termination or power loss, and
it does not make synchronous validation responsive while the event loop is busy.
No original production source, legacy save slot, game rule or visual asset changes.

## Qualification and evidence boundaries

Tests use an App subclass overriding only the final process-termination action.
They drive real Godot signals, dialog buttons and WM-close notifications. This
is headless native engine behavior, not a desktop window-manager click or visual
acceptance. Structural retained/busy/completed guards are labeled as such; no
invented completed gameplay is counted as an earned result.

The actual round qualification preserves a separate pre-pack open-shop checkpoint
from real human and NPC results. The runner copies it to a newly isolated HOME
and XDG tree, never replacing the paid-round evidence. Actual full-shop reroll
buttons exercise Cancel, OK, repeat confirmation, an injected pre-write refusal,
blocked exit and exact-candidate retry using earned Cash. Main and pre-pack bytes
are checked unchanged by this alternate branch. The source checkout and user's
original saves are never launched or touched.

Final-source Godot 4.6.3 qualification passed:
- Actual unfinished-match dialog controls, cancellation, repeated/conflicting
  actions, stale season/lab/state pins, all retained/busy/completed guards,
  retention arising after confirmation opened, and prior quit-policy restoration.
- Fresh Standard human and two NPC games, once-only settlement/rewards, earned
  generated pack payment/application, and cold exact reopen/overwrite refusal.
- Actual durably pending human checkpoint permits close with unchanged bytes.
- Actual earned full-shop Cancel/OK/repeat, exact pre-write refusal preserving
  primary/backup, blocked close, and identical retained-candidate retry once.
- Alternate shop branch leaves main paid and original pre-pack bytes unchanged.
- Manifest byte/hash checks, final production source equality in native stages,
  Python compilation, whitespace checks and source-only publication audit.

The late-retention assertion was added only to test code and passed in a separate
final-source standalone interruption run. The actual round used the same final
production bytes. Other profile rounds were not rerun for this UI-only change;
the preceding B3 checkpoint records their separate qualification. This change is
not a full-season, career, Dynasty, visual or distributable-build completion.
