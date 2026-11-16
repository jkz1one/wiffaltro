# Wiffaltro source recovery and active candidate

The baseline at commit 198d56d54003753b52a0209ce9f09337a6f37aa4 preserves the surviving November 12 R6 source. This branch does not recover the missing later Standard v7 work.

## Current candidate

The reviewed background-save integration now includes a single-use committed-checkpoint receipt to avoid saving the same pending result again on Continue. A missing or mismatched receipt falls back to the existing validated save path. Historical save formats, catalog inputs, and ownership rules are unchanged.

The combined native save/receipt/Continue/cold-reopen test is pending. The previous candidate compiled all 11 changed scripts and decoded the retained game, but its test broker stopped before launching a save worker because a Linux process-evidence interface was unavailable. The correction uses the existing supervisor's PPID evidence with unchanged child ownership and time/resource limits. That earlier test did not qualify saving.

No release, measured speedup, visual acceptance, or completed remaining-round claim is made.

BACKUP_MANIFEST.json records the baseline. ASYNC_SAVE_CANDIDATE_MANIFEST.json records the initial 14-file background-save delta. RECEIPT_CANDIDATE_MANIFEST.json records this subsequent four-file source/profile delta. These manifests describe their respective revisions, not all later hashes.

## Recovery scope

The audited payload contains all 1,246 current production/profile inventory paths with matching hashes. The 135 excluded paths are optional saved-game fixtures, machine-specific tests and associated UID files, and notes, not production dependencies. Source-game recovery does not require publishing them. A fresh-checkout startup check remains pending. This is not a verified standalone export or complete historical regression archive.

No player saves, local Git history, machine-specific provenance, caches, logs, output archives, credentials or private notes are included. Keep actual saves and private evidence separately. Development engine: Godot 4.6.3 stable. Preserve source and UID bytes during recovery; rebuild only generated engine cache/import data. Main and all other existing branches remain unchanged.
