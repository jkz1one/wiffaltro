# Successor signature repair — 2026-11-16

## Verified starting point

Recovery branch `backup/recovered-r6-source-20261116` was read remotely at
`3db8e53542a79dcabe159d818abf5b756fde1c9a`. All 47 inactive successor draft files
matched their manifest before restoration into an isolated test project.
The Library league blueprint v4 was reviewed. Its historical tests do not certify
this recovered source or the successor draft.

## Defect and narrow change

The original draft's `signature()` called `_new_recipe()`, which deliberately
returns detached pitch/delivery Resources. The detached delivery has an empty
`resource_path`; hashing it returns an empty digest and rejects the signature.
An isolated native run reproduced both the empty signature and failed fresh
season creation. The authored delivery retained its actual resource path.

The fix reads the authored Resource for source hashing only. Public gameplay
recipes remain detached, and catalog validation and historical identifiers are
unchanged. The draft manifest records the changed file's current size/hash.
Its `source_manifest_sha256` remains historical provenance, not a new aggregate.
No live `src/` file or project configuration is modified.

## Reproducible checks

Run `python tools/test_successor_signature.py` with Godot 4.6.3 available.
The runner validates the manifest, copies source to a new temporary project,
materializes inactive draft/test files there, and isolates HOME plus all XDG
config/cache/data locations. It never opens the owner's saved games.

Native Godot 4.6.3 checks passed:

- Import/parse of the restored candidate.
- Nonempty deterministic signature; 41 active and 50 known recipe identities.
- Each new pitch retains a detached delivery; mutation of that copy leaves the
  authored Resource and signature unchanged.
- Original v5 catalog signature unchanged.
- Fresh successor creation, capture, JSON restore and exact recapture.
- Real successor save through its own persistence implementation.
- Fresh legacy save remains byte-identical after the successor save.
- Separate cold process reopens both fresh successor and fresh legacy saves and
  recaptures exactly their persisted payloads.

An initial command-line script test setup failed because its early preloads
could not resolve the project's ContentDB autoload. The corrected test runs as a
normal scene; that setup failure is not treated as a gameplay failure or pass.
Logs and generated test saves remain outside the repository.

## Scope limits

The successor draft remains inactive and standalone. This is not Dynasty,
career, a completed draft/match/round, shop, full-season, visual or export
qualification. Legacy coverage here is fresh save/reopen plus unchanged live
source/signatures, not an exhaustive historical-save regression. Later lost
career/shop/performance/round work remains absent and must be rebuilt/retested.
