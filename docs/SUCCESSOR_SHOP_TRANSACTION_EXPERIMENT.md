# Unbound fixed shop transaction experiment

This separate namespace is not connected to any production App or current save
reader. Existing General114 engine bytes, catalog identities and saved evidence
remain unchanged. It is not a persistent-owner reader or a general trusted-save
API. The current App still uses its original clone, mutation and Save paths.

## Authority and lifecycle

The sole fixed operation accepts a live season and a shop command. Within one
synchronous call it holds authored Resources, acquires the existing save guards,
captures and strictly restores the old season, applies the unchanged supported
shop command and lineup adoption, and fully validates the changed candidate.
It retains the existing JSON precision, size bound, recapture, temporary-file
readback, unchanged-disk check, backup copy and primary readback requirements.

Old primary validation may be reused only when its parsed complete JSON equals
the detached old payload strictly restored inside that same call. A different
primary receives its own full restore. No caller-supplied validation token,
callback, revision shortcut or persistent cache can authorize this reuse. The
local callable is only an early-return cleanup boundary; it is not supplied by
the caller. All old-state proof dies on return. A failed write returns the exact
candidate for a later ordinary full Save.save retry, without replaying the shop
command. The candidate is not automatically published into an App.

## Qualification scope

The isolated test uses an authentic earned, paid Standard checkpoint from the
unchanged checkpoint31 engine. It spends actual remaining Cash on an affordable
reroll, comparing the changed candidate, charge, journal, primary and backup
against the unchanged full reference route. Each scenario has its own isolated
save directory; the source fixture and original user saves are not written.

Scenarios cover matching primary, equivalent JSON with different formatting,
a different valid primary requiring fallback, malformed primary preserving its
valid backup, and a real temporary-directory write obstruction followed by an
ordinary full-save retry. Each checks a new-ID stale revision rejection, caller
and authored-Resource invariance, and a separate cold full public reopen.

Godot 4.6.3 passes all five scenarios above and a separate cold full public
reopen after each, against the final candidate source. This is not broad
App, Academy, recruitment, Equipment, multi-round, or owned/Dynasty qualification.
The test prints a single warm candidate duration under concurrent load. It does
not time the complete reference transaction and establishes no production
speedup. General114's source-bound identity would change on production
integration and require fresh gameplay qualification rather than relabeling old
fixtures.

An initial malformed-primary run produced the correct candidate and preserved
the backup, but the static JSON parser logged an error, correctly failing the
strict harness. The experiment now uses the parser's explicit error return for
untrusted old disk JSON; malformed data still cannot authorize backup replacement.
The failed evidence remains preserved. This correction does not suppress harness
errors or change the current production Save implementation.

Further unqualified cases include async-lock refusal, a missing or oversized
primary, an existing temporary file (rather than directory), and copy/rename or
post-write failures. The existing possibility of an external writer changing the
file after the final prewrite comparison is not solved by this experiment.
Malformed-primary success replaces that invalid primary while retaining the
previous valid backup; it does not certify malformed data.
