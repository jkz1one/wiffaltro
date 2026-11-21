# Common Base league transition: durable proposal

The current Common V4 creator otherwise has a single Ordinary slot and
its legacy Next is same-league. This increment implements a distinct
versioned Store proposal from an actually closed, complete first Standard
Base season to Dugout Base, not a second inactive data format. Both leagues
are available in the authored starting policy; the original fixture has
no Standard title. Other league/side/tier/ordinal sources are not exposed.

The producer requires an already strictly admitted live Owner, exact
primary bytes and matching raw snapshot. It derives the target seed/ordinal
and start basis from canonical rules and the current common earned rights.
Its typed proposal binds the original league, Base tier, native close ID,
unchanged terminal snapshot digest, target league and Base tier, and
ordinal 2. Only the proposal changes. All 33 result rows, complete
physical archive, Close and banked rewards/rights remain in the active
season, not just in the rotating backup. The same-session Store ticket
uses the existing atomic write/retry/readback. The normal continuation
cannot consume or overwrite this typed proposal; historical untyped
proposals remain same-league.

The producer requires the earned preview plus
`WIFFALTRO_CROSS_LEAGUE_PREVIEW=1`, but no interactive control calls it.
The initial source proof measured about 7 seconds for a 7.7 MB terminal
owner even without replay inside the proposal. A native cold Continue
can display the saved intent and the unchanged closed season; no
activation, draft, entitlement, or payout is granted there.

Attach `tests/successor_common_cross_league_proposal.gd.txt` to a scratch
Node in the source-preserving Linux Godot 4.6.3 assembly. Use disposable
profiles, exact generated CP170 closed primary and predecessor, and the
isolated/common/earned flags. Run `-- flag-off <closed SHA>`,
`-- propose <closed SHA>`, and `-- cold <proposed SHA>`. The QA native
owner calls the Store directly; a temporary test-owned obstruction must
preserve both files, then retry the same exact ticket. Separate cloned
controls use `-- preclose <actual active complete SHA>` and
`-- legacy <closed SHA>`. No games are replayed.

Activation is held for the next implementation: add one bounded flat
predecessor archive that survives subsequent writes and switches, validate
that complete stored proof off-frame, recheck the exact CAS/target/prior
close and common rights, and only then replace the current Ordinary
session. Preserve the exact parked Dynasty snapshot and workshop metadata;
this genuine test fixture has no parked Dynasty, so only absence
preservation is directly exercised here. Never rely on .bak or nest
entire archives. The chosen born season must still be independently
cold-read before advertising the route as playable.

For the checked source, the prepared proposal (seed 1002) is
`b6727d56f89e723c3b7c73a25ba3ed198a707997ef5f000eb7b5c92945aa0acb`.
Its predecessor is the unmodified CP170 closed
`1a226548fad8932770868dcb286d1466a30976d571c2238ed78964fefb02b082`.
Independent raw comparison found the 7,697,177-byte Ordinary payload
verbatim in the new primary. Outer Common/Close numbers can change JSON
whole-value spelling on the native writer, but all values and rights
outside the proposal are identical. The obstruction plus exact-ticket
retry and handoff measured about 9.4 seconds in headless Linux, not a
target-hardware or interactive response claim.
