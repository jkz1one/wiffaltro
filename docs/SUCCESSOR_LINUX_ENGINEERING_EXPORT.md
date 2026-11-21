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
We have not exercised stadium placement, the legacy same-binary worker,
rendered controls, audio or performance, native Mac, or public progression in
this package. The current private Doubleheader and Dynasty restrictions
remain unchanged.
