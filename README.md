# Wiffaltro source recovery and active candidate

The baseline snapshot at commit 198d56d54003753b52a0209ce9f09337a6f37aa4 preserves the surviving November 12 R6 source. This branch does **not** recover the missing November 15 Standard v7 work.

## Current candidate

A narrowly reviewed background-save integration is now installed in the development workspace. Its **native compile/save/cold-reopen test is pending**. This is not a release, and no speedup or gameplay acceptance is claimed. Supported standalone expanded-pitch source builds use background validation; unsupported routes retain the existing synchronous save path. Original save formats and catalog inputs are unchanged.

ASYNC_SAVE_CANDIDATE_MANIFEST.json records this 14-file source/tool/profile delta. BACKUP_MANIFEST.json records the original baseline snapshot, not the current modified hashes. The baseline remains recoverable from its original commit.

## Backup scope

Includes runtime source/resources and safe test source. No player saves, saved-game test fixtures, local Git history, machine-specific provenance, caches, logs, output archives or private notes are included. Some excluded fixtures and qualification resources are referenced by code, so this branch alone is **not a verified standalone playable package or complete qualification restore**.

Development engine: Godot 4.6.3 stable. Preserve historic save formats. The completed November 12 paid-pitch game must not be replayed merely to rebuild evidence. Main and all other existing branches are unchanged.
