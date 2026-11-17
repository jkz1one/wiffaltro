# Same-call ordinary human replay prefix reuse

## Narrow change

The generalized ordinary decoder fully validates the final Build journal, then
reconstructs each human game's pre-reward Build twice: once for the heat replay
team and again for human evidence/reward replay. The new private combined helper
owns one restoration and uses that exact prefix for both synchronous operations.
It accepts no caller-supplied validated prefix, invokes no observer, and retains
no cache, token or decoded state beyond the operation.

Only the existing admitted ordinary leaf57 / Game114 route is eligible. Venue,
inventory, Doubleheader and foreign evidence branches keep their old behavior.
Full final-journal restoration, saved evidence checks, roster/League checks,
called-pitch proof, result recording and subsequent full history/reward/recapture
comparisons remain. Public HumanReplay.result and ReplayTeam.replay_team retain
their original independent restorations byte-for-byte.

The private decoder's diagnostic switch selects either this route or the original
two-restoration route. It is not a validation or trust flag; both routes perform
all semantic checks. Public Codec.restore always uses the default optimized path.
The static two-to-one call routing is not presented as a measured runtime counter.

## Qualification gates

Godot 4.6.3 passed against the current source:
- All 47 structural Build/Development regression cases.
- Fresh and fully drafted six-profile reference/combined/public Codec parity.
- Newly generated Standard human plus two NPC games, once-only settlement, earned
  pack purchase/application and cold reopen.
- That actual paid history: exact full recapture on both paths, malformed journal,
  missing/reordered reward, result/roster/tactics/pitching/foreign-ownership
  rejection and failed-then-valid recovery.
- Unchanged caller input, isolated primary/backup/temp bytes and held authored
  Resource storage-property graphs during both ABBA routes/public restore.

Actual Academy pending/two-choice and multi-round Equipment regressions are still
running at this source checkpoint. Their earlier checkpoint results are not
claimed as passes of this changed source. The Standard stage began before the
two new comparison test files were added; only those test files were added before
the comparison, and all staged production bytes matched the final source.

The first paid-history ABBA sample does NOT establish a speedup: two reference
samples averaged 12.064650s and two combined samples 12.446446s, about 3.2% slower
in this small concurrent-run diagnostic. No responsiveness improvement is claimed.
The structural duplicate removal remains a bounded candidate pending later-history
measurement, not a solved performance problem.

ABBA samples, when reported, time a warm held-Resource diagnostic restore wrapper
including its ordinary boundary validation and exact recapture. They are not cold
process startup, whole user interaction, hardware projections or release targets.
Fresh/draft cases have no human result and are parity controls, not speed evidence.

The original project and frozen save families are untouched. New generalized
source hashes require newly earned fixtures; older saves are not relabeled. This
remains inactive staging, not persistent career/Dynasty or release qualification.
