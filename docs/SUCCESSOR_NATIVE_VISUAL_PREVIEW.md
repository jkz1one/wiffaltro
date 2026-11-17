# Bounded native presentation QA

The verified checkpoint 43 reroll entry was rendered in a fresh isolated clone
using Godot 4.6.3 and OpenGL/Mesa llvmpipe. Original development visuals were
unchanged. Source, original generated saves and copied fixture were preserved;
all 6,422 original stage files remained byte-identical. Only two new clone-local
Godot UID companions were generated for newly materialized scripts.

Inspected 1228x691 menu, initial Shop and pre-pitch gameplay captures show readable
roster rows, controls, offer text, scoreboard and pitch HUD, without visible
overlap in those captured regions. Lower-shop, reroll quote and cancellation
captures at 1280x720 are also readable. Those PNGs are scripted actual-control
views with commit/save/result paths disabled, not purchased or played outcomes.
Separate native scrolling, reroll-button activation and Cancel were observed at
1228x690: the quote showed 4 Cash to 0, and cancellation left 4 Cash unchanged. No OK
purchase was attempted in native visual QA; actual purchasing is qualified by
the separate transaction/App tests, not these images.

## Diagnostics and limits

The native debugger showed 411 total entries, not an all-warning or clean result.
One sampled red audio initialization `ERR_CANT_OPEN` was observed, followed by
fallback to the dummy driver. Sound is unqualified. There was also an unsupported
V-Sync warning and sampled GDScript warnings for static calls through instances,
shadowed names, incompatible ternary types, integer division and unused signals.
Samples include active classes. Exactly one observed red entry is a lower bound,
not an exhaustive count; every category/entry was not classified.

No source was changed to hide diagnostics. Original captures/reports and a
corrective diagnostic addendum remain preserved in private evidence. No full
visual, animation, timing, batting/pitching input, frame-rate, audio, alternate-
resolution, Dynasty or distributable acceptance follows from this bounded pass.
The native preview/editor were closed after inspection; headless season work was
not operated or interrupted.
