# Private macOS engineering export

The Linux-host build uses the official Godot 4.6.3 Linux x86-64 editor
and matching vendor non-Mono export templates. It runs offline, requires a
new scratch output directory, and does not need, copy, or load a save.

```sh
python3 -B tools/build_successor_engineering_macos.py \
  --godot /absolute/path/to/Godot_v4.6.3-stable_linux.x86_64 \
  --templates /absolute/path/to/Godot_v4.6.3-stable_export_templates.tpz \
  --output /new/scratch/wiffaltro-mac-qa
```

The only candidate artifact is `package/WiffaltroEngineeringQA.app`. Scratch
source, generated editor caches, logs, and template archive are not deliverables.
The bundle uses an internal placeholder identifier and an isolated
`WiffaltroEngineeringQA-v1` user-data directory. It retains the actual gated
common career launcher and the original worker dispatch. Keep the environment
gate; this is not a public beta or a distribution workflow.

The builder verifies the vendor archives, source assembly and reviewed
stadium gate, keeps raw text and the exact authored `project.godot` alongside
the effective package settings, and checks the regular-file bundle layout,
executable permission, and both native Mach-O slices. The Linux editor mounts
the actual Mac PCK from an empty working directory and compares its resource
hashes against the staged inventory. The broad stadium digest is an observation,
not an approved pin. No full test tree, external audit script or save belongs
in the bundle; the small original support closure is explicitly retained.

## Native evidence still required

This does not run a Mach-O binary, and signing and notarization are deliberately
disabled. macOS security may refuse the artifact; do not weaken OS settings
to get around a refusal. Review the authorized signing/distribution route
separately. See [Godot's macOS export guidance](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html).

On a native test Mac, use a disposable OS user, never an existing game profile.
Verify the exact bundle and verify the engine resolves the isolated folder
before copying any generated QA save. Record OS, CPU/GPU, process architecture,
renderer, Godot version and hashes. Test ungated refusal, gated first launch,
rendered input/audio, actual pitch/bat play and same-binary NPC worker,
settlement, and a separate-process Continue from the same copy. Profile
launch-to-menu, Continue-to-control, gameplay and settlement separately.
Offline pack inspection cannot attest to any of those.

## Observed offline result

The CP164 source produced a six-file Universal 2 app bundle using the pinned
vendor templates. A second isolated Linux process mounted the actual macOS
PCK and verified 3,022 raw resource hashes. A deliberately incorrect
bootstrap hash was rejected. The measured executable SHA-256 was
`5a65c5e1fc81bb7816b03e1be1f902de58c1ff4b71b9a83973665f35d4f4e737`
and PCK SHA-256
`f2d237934f39787a5fbcd513a755e4029acff1ccaa7d2afd15d189efec1c705c`.
These describe this exact artifact, not a reproducible-signature promise.
The app has not been executed on Mac hardware.
