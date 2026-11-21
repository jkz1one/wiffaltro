# Standalone Linux integrated engineering candidate

This is a headless qualification of the current integrated common career entry,
not the beta, a user-facing package, or proof of rendered playback. It uses the
official Godot 4.6.3 Linux x86-64 release template and keeps
`WIFFALTRO_DYNASTY_ENGINEERING=1` mandatory.

```sh
python3 tools/build_successor_engineering_linux.py \
  --godot path/to/official/Godot_v4.6.3-stable_linux.x86_64 \
  --templates path/to/official/Godot_v4.6.3-stable_export_templates.tpz \
  --evidence path/to/previously-backed-generated-cp88-evidence.zip \
  --output path/to/new/scratch-directory
```

Only the ELF and adjacent PCK are executable package inputs. The scratch build
and evidence directory contains generated import data, logs and isolated
copies of backed synthetic saves. Do not publish that directory or put the
save fixture inside the PCK. Original project files and saved profiles are
never altered. The test package has its own `WiffaltroEngineeringQA-v1` data path.

The executable's effective compiled configuration selects the integrated
launcher and engineering data path without changing game or engine settings.
A temporary editor-only export plugin retains the exact reviewed raw
`res://project.godot` as a resource for the real source-provenance check.
GDScript is exported as Text and raw text resources are preserved; using a
normal text-to-binary remap can remove a path that `FileAccess` must hash.
A small exact compile/provenance support set is retained from the original
development tree. No full test tree, test fixture, pack auditor, export plugin,
or save ships in the two-file result.

The test first runs the existing reviewed stadium check on exact unmodified
raw source. Then it requires the actual standalone executable to reject
launch without the engineering flag, boot the integrated entry from an
empty working directory, and use the isolated data path. A separate process
with the matching editor binary mounts only the exact PCK, uses the real
native reviewed stadium check on all 1,246 original paths, verifies raw
source bytes and strictly reads an authentic generated earned career with
the original paid Dynasty pack choice and parked ordinary season. Neither
save slot may change in that proof. No test script in the PCK is used.

**Not approved for distribution.** The broader whole-tree identity for Pool
Party, Timber and paid stadium placement is separate and its digest differs
in the curated package. Do not refresh that allowlist from packaging output.
The automated headless test does not exercise stadium placement, the legacy
same-binary worker, rendered controls, audio or performance, native Mac, or
public progression. The current private Doubleheader and Dynasty restrictions
remain unchanged.

## Rendered Linux smoke test of the same two-file package

The same ELF/PCK was also run as a real window in a disposable Linux desktop
at 1100×680. The VM fell back from Vulkan to Mesa llvmpipe OpenGL; this is not
a performance or Vulkan qualification. With a copied authentic earned save,
the visible Continue and both Resume buttons switched from Dynasty to the
closed ordinary season and back. At the rendered shop, Cancel left 4 Cash and
the exact original owner. A new confirmed Swing Plan purchase cost 3 in-game
Cash once and held one item. After stopping the idle foreground test process
and starting a new process, Continue and Shop visibly showed 1 Cash and one
held item. This tests fresh-process durability, not a graceful OS quit.

`verify_successor_packaged_shop_trace.py` checks the two exact package hashes,
the authenticated original archive, the post-Cancel primary, the earlier
observed paid hash and the post-reopen primary/backup. No input or screenshot
is embedded in the package. This adds genuine rendered mouse/menu and shop
evidence only: no rendered match, external controller, audio or native Mac
test follows. The separate stadium-placement and legacy worker gaps remain.

## Packaged legacy worker boundary

The integrated build can reach the original game. That older mode starts the
same exported executable for an offscreen match. Its command has
`--physical-job` but no scene path; a normal integrated menu must not receive
that command. The packaging-only bootstrap routes normal launches to the
same integrated launcher, and valid engineering/headless worker launches to
the unchanged original scene and its own original worker dispatcher. It
rejects malformed jobs and remains behind the same engineering flag.
It is packaged outside `src`; neither existing stadium identity changes.

For the test, assemble a disposable source tree, restore the exact original
`project.godot` in the copy, and place
`tests/successor_packaged_legacy_prepare.gd.txt` as a scratch `.gd` attached to a
Node scene. In a unique empty test HOME/XDG environment with
`WIFFALTRO_ISOLATED_TEST=1`, invoke that scene with `-- draft` (stock seed 443,
four actual picks), and in the same isolated home invoke `-- capture` to play
and durably queue the actual original fixture. This uses the current original
App's managed capture; an older flat-format helper cannot read this bound
report. Do not retry capture after a retained original report exists.

`tools/test_successor_packaged_legacy_worker.py` takes that prepared local
save directory, the new packaged build directory, and the matching editor.
It starts the **actual release ELF** with original worker arguments after
checking the ungated and missing-request refusals. The original worker
produces a physical report against the authored projected fixture. A second
process with the mounted PCK calls the unmodified native parent validator
and rejects altered fixtures and request identities. Both source slots and
the request must stay byte-identical. This is an actual worker transport
test and an independent native report check, **not** a claim that the
packaged parent UI launched it, both fixtures settled, or that the separate
broader stadium authority passed. The previous rendered shop evidence
belongs to its original exact package, not this updated worker package.

## Original-game Save98 round recovery

The packaged parent window launched both AI fixtures and kept both validated
reports. It then failed to commit the round: the original Save98 generic
replay called the native result recorder with no pitching evidence, while
live settlement had used the retained human report. This was a save replay
bug, not a failed worker or a GPU issue. The unchanged original and mounted
package both projected the same final snapshot and both refused to decode it.

The fix feeds the already-validated current pitching sidecar (or the saved
legacy pitching dictionary when no sidecar exists) back into that same native
replay only for Save98. Existing catalog, projection, journal, and report
validation remains in place. Other version-specific replay paths are
unchanged. The fixed stadium provenance manifest changes only the exact
digest of this one reviewed dependency; the historical broad allowlists are
unchanged. The new Linux engineering pack compares every raw file, rechecks
all 1,246 reviewed paths, and reads the previously earned, independent
Dynasty and ordinary save without changing its slots.

With the exact two-report synthetic copy, the rebuilt official Linux ELF in
a normal window advanced from Round Waiting to an 11–5 win, paid 18 in-game
Cash, and showed Game 2 of 10 with a 1–0 record. The window logged two
retained fixtures and started no new worker. The atomic save contains the
same two reports, one journal reward for each of the six clubs, and no
unsettled fixture. After an in-game Quit, a newly launched window reopened
at Game 2 with the same 1–0 record and no new retry. The two on-disk slots
were unchanged by the reopen. The original one-report backup and two-report
input remain unmodified outside the disposable profile. This tests recovery of the
original-game path, not a round played through the integrated Dynasty UI
or distribution on macOS.

Given the exact local synthetic pending checkpoint and its sibling backup,
`tools/test_successor_packaged_legacy_settlement.py` runs source and mounted
PCK replay using new isolated profiles. It checks six single receipts,
unchanged reports, strict validation, altered catalog/pitching/report
refusals, byte-identical output, and a distinct cold process. It does not
start physics workers, derive a save from hashes, or accept player saves.
