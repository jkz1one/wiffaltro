# Fresh successor owner draft foundation

Inactive additive owner domain. Requires unchanged League109 gameplay and the
separately signed successor career-evidence domain. Neither existing source nor
existing save slots are modified.

- API: Runtime.create_fresh(seed), Codec.capture/restore/scope, Save.save/restore.
- Outer version110, format `successor-fresh-owner-draft-v1`.
- Owner-source identity binds these adapters plus frozen game and evidence identities.
  Build/Book/report pitch identity stays the unchanged Game109 identity.
- Separate slot: `user://successor-fresh-owner-draft-v1.json`.
- Admission: genuine first owner, Dugout0, zero through four draft choices only.
- Complete original initial career starts and owned draft access are installed before
  picks. Runtime remains a new concrete script; Game Build/Book/Opponents are reused.
- No results, rewards, purchases, physical reports, pending work, inherited Exotic
  history, prior runs, completion/abandonment, Dynasty or other League admission.

Codec never strips career/access to feed a Game109 snapshot. It serializes every
known primitive SeasonState field plus explicit owner, Build, development, view,
opponents, ownership and physical values. An unknown script variable fails closed.
Restore reconstructs a pristine genuine owner, all starts and owned access, then
replays each draft choice. It accepts only exact complete recapture equality. Saved
owner rows or claimed starts are never installed as authority. Career metadata uses
its own version1/format and remains embedded atomically in this envelope.

Runtime's structural start handshake is distinct from persistence admission. Its
owner binding uses the new exact owner script, not historical ClubLeagueCareer
admission. Codec and draft actions additionally require complete Start.matches.
Gameplay and shop entry remain intentionally closed for this checkpoint; owner-aware
round settlement/pending replay and progression follow in a later verified step.

This is not full career or Dynasty completion. Native current-run tests and isolated
cold-save evidence are required before checkpoint qualification. Keep saves, raw
evidence, caches and private data out of this source directory.

### Shared source identity boundary

OwnerCatalog additionally hashes an explicit sorted list of 200 original source
files for fresh-owner birth, initial asset serialization, access entitlement,
draft allocation and validation. It includes ClubPlayerDraft and the original
SeasonState schedule helpers. The list is deliberately not the entire historical
static dependency graph: dormant historical career, purchase and render workflows
are not admitted. Catalog signature/initial-value helpers called by the pristine
asset ledger are included transitively. Some live stadium model files supply
catalog constants even with no purchases (for example StadiumLightItems.signature
reads StadiumYardLightModels.SITES/VERSION and StadiumYardNightPrototype.VERSION).
Their presence does not enable stadium construction/render operations. Asset
ledger operations 10–13 provide empty-event classification during serialization.
All source hashes are freshly read per identity operation; no validation-result
cache or source bypass is used. Game109 pitch/report identity remains unchanged.
