# Wiffaltro surviving source recovery snapshot

This branch preserves the surviving November 12 R6 game source, backed up on November 16, 2026. It does **not** contain the missing November 15 Standard v7 work.

The original source bytes are unchanged. The snapshot contains project.godot, runtime source/resources and safe test source. BACKUP_MANIFEST.json records every included source hash and explicit exclusions.

No player saves, saved-game test fixtures, local Git history, machine-specific provenance, caches, logs, output archives or private notes are included. Some excluded test fixtures and qualification resources are referenced by the code, so this source snapshot alone is **not a verified standalone playable package or complete qualification restore**. No game or test was rerun for this backup.

Development engine: Godot 4.6.3 stable. Preserve historic save formats when continuing development. The completed Nov 12 paid-pitch game must not be replayed merely to rebuild test evidence.

This is an independent recovery branch. It does not change main or other existing branches.
