# Byte-preserving PCK compatibility probe

This is a diagnostic resource pack, not a distributable game. No export templates
were installed or standalone application produced. The installed Godot 4.6.3
editor-capable binary ran both unpacked and packed checks headlessly with Dummy
audio; target-platform binaries, native PCK graphics and sound remain unqualified.

## Supported configuration and verified result

The isolated preset uses GDScript export mode Text (0), all resources plus explicit
source inclusion, and `editor/export/convert_text_resources_to_binary=false`.
This avoids changing raw identity-bound script/text-resource bytes. These settings
are supported by the tagged Godot [GDScript exporter](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/modules/gdscript/register_types.cpp)
and [platform exporter](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/editor/export/editor_export_platform.cpp).

Actual baseline, template-free `--export-pack`, PCK execution and separate cold
PCK execution passed. Packed processes ran with both working directory and
`--path` pointing at an empty directory, preventing an unpacked project fallback.
They matched all 6,282 staged source-file hashes, General/Provider/legacy catalog
signatures and nine held authored root paths. They strictly reopened an authentic
copied paid Standard save. The first packed process created a fresh season,
completed four picks and saved through the real Save; a separate packed process
restored that exact drafted save. No gameplay result was fabricated or played.

Observed private diagnostic PCK: 28,523,232 bytes, SHA256
`e5cc0a1646032815df4ce571a68de39b2b8eb6ad9deacdec4268964b87914eb6`.
Only the isolated runner should launch this test pack; it is not a player build.

## Provenance and retained failure

Every existing staged source file matched repository source or a hash-verified
manifest materialization. The only exceptions were 195 syntactically valid
Godot-generated `.gd.uid` sidecars with exact audited script companions; their
bytes were retained and included in baseline/PCK hash checks. No duplicate UIDs
were found. Original stage, original fixture and all copied existing source bytes
remained unchanged. The paid fixture lived only in isolated user data, not PCK
resources. Source configuration also matches the repository exactly before the
probe changes its private clone settings.

The first attempt's empty preset-options section produced a Godot configuration
error and remains failed evidence. An explicit standard option corrected only
test setup. The successful run's probe/core files were final; subsequent Python
hardening adds an independently satisfied source-config equality precondition
and explicit rejection of `FAIL:` logs. All successful logs were checked against
those requirements. No safety restriction was bypassed.

This demonstrates a byte-preserving packaging route, not that partial semantic
identity is complete. Future source updates still require a deliberate save
compatibility/migration design. Standalone templates and intended target hardware
must repeat raw-identity, authored-input, actual-save and cold checks before any
build is called verified or ready to play.
