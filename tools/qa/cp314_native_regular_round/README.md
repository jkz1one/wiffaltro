# Scoped earned regular-season QA
CP314 uses this QA-only harness on the pinned recovery build; no production edits.
Build: build.py CHECKOUT EDITOR LINUX_ELF.
Run: run.py PROOF_ROOT PAID UNPAID_BACKUP EMPTY_CUSTODY PAID_SHA256 BACKUP_SHA256 BASE_ROUND_INDEX.
Use a separately authenticated synthetic fixture only. Base index is explicit,
bounded to 2–8 and validated against the exact recorded schedule/physical roles.
The actual responsive Continue plays one round, persists four exact owner
boundaries/witnesses with readback before continuing, pays once, then cold
reopens from exact paid and unpaid .bak into a fresh native App. No earlier
round/purchase replay, no next match, no postseason or real player profile.
