# Wiffaltro source recovery and active candidate

The baseline at commit 198d56d54003753b52a0209ce9f09337a6f37aa4 preserves the surviving November 12 R6 source. This branch does not recover the missing later Standard v7 work.

## Successor development status

Active successor integration is tracked in [the qualification status and gates](docs/SUCCESSOR_INTEGRATION_STATUS.md). Additive drafts and isolated tests do not replace the original project entry or constitute a playable release. The recovered-baseline notes below describe their historical candidate, not the later successor qualification.

## Recovered baseline candidate

The reviewed background-save integration now includes a single-use committed-checkpoint receipt to avoid saving the same pending result again on Continue. A missing or mismatched receipt falls back to the existing validated save path. Historical save formats, catalog inputs, and ownership rules are unchanged.

A small operation-scoped resource-hold optimization is now installed: existing pitch manifests/retired Resources stay alive only during each expanded save snapshot or decode. All validation, source hashing, replay and original results remain unchanged; there is no persistent result cache.

The next real save/receipt/Continue/cold-reopen test is pending. The previous source candidate compiled and loaded the retained game, configured the actual UI and launched its real save validator, but reached the 300-second limit before replacing the save. Original input and isolated primary remained unchanged and all processes were reaped. That timeout remains failed evidence, not a save pass. Earlier test setup issues were corrected separately.

No release, measured speedup, visual acceptance, or completed remaining-round claim is made.

BACKUP_MANIFEST.json records the baseline. ASYNC_SAVE_CANDIDATE_MANIFEST.json records the initial 14-file background-save delta. RECEIPT_CANDIDATE_MANIFEST.json records this subsequent four-file source/profile delta. OPERATION_HOLD_CANDIDATE_MANIFEST.json records the subsequent two-file performance candidate. These manifests describe their respective revisions, not all later hashes.

## Recovery scope

The audited payload contains all 1,246 current production/profile inventory paths with matching hashes. The 135 excluded paths are optional saved-game fixtures, machine-specific tests and associated UID files, and notes, not production dependencies. Source-game recovery does not require publishing them. A fresh-checkout startup check remains pending. This is not a verified standalone export or complete historical regression archive.

No player saves, local Git history, machine-specific provenance, caches, logs, output archives, credentials or private notes are included. Keep actual saves and private evidence separately. Development engine: Godot 4.6.3 stable. Preserve source and UID bytes during recovery; rebuild only generated engine cache/import data. Main and all other existing branches remain unchanged.
