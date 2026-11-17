# Additive resource-retaining transaction facade

The optional App subclass retains authored Resource references only for each
synchronous transaction call and then releases them. It invokes the unchanged
parent implementation. It introduces no identity/result cache, no validation
shortcut, no asynchronous lease, no save format change and no migration.

All frozen owner111/110, career evidence, League and standalone source bytes remain
unchanged. Existing owned checkpoints retain their original identity and slot.
The new entry scene is separate; the original production entry is unchanged.

## Qualification

The isolated benchmark compares baseline and facade in ABBA order on identical
copies of an actual earned owned-round checkpoint. Each purchases a generated
legal item with real earned Season Cash, then performs the same fresh-owner draft
choice. Exact candidate and disk payloads must match the baseline. A separate
blocked-save trial checks retained candidate integrity, blocked repeated action,
and exact retry. A cold process restores the paid and drafted results and the
original checkpoint under the unchanged codec.

This benchmark does not constitute new gameplay, complete career, Dynasty,
visual playtesting, or distributable-build qualification. Verified results and limitations are recorded below.

## Resume and coverage notes

The November 17 workspace recovery found this facade unfinished at remote
`e83a1ba`. Prior temporary owned-round fixtures were unavailable, so new baseline
and facade native-game fixtures were created rather than reconstructing scores.
A second executor interruption stopped both after their durable second AI report.
The source and both isolated save trees survived. An explicit `settle-only` test
mode now cold-restores that two-report checkpoint before settlement; the normal
runner also splits that boundary into a separate process. Interrupted log tails
are retained and are not counted as completed test passes.

`--owner-round --facade` selects this App explicitly and prints its script path.
It covers real human gameplay, both AI callbacks, cold pending boundaries,
settlement, shop failure/retry and cold purchased reopen, rather than inferring
those wrappers from the purchase/draft microbenchmark. Parsed payload equality
is distinguished from raw-byte source preservation.

## Verified native gameplay and measured ABBA samples

Godot 4.6.3: baseline seed `1794875086` and facade seed `1794875220`
completed actual human-side and two AI games. Both durably reopened the two-report
pending boundary, settled once, purchased an earned pack through full-shop
confirmation and deliberate failed-save retry, rejected forged state, and reopened
cold with exact active-career payload and preserved original draft-owner slot.
The interrupted second-AI process tail is not a standalone process pass; its
durable report was subsequently validated by the cold settlement process.

A separate identical pre-shop settled fixture (real earned funds) produced these
ABBA samples. Shop opening was untimed setup; timed actions include normal strict
validation and persistence. No fabricated cash or result was used.

| Trial | Purchase ms | Draft ms |
| --- | ---: | ---: |
| baseline | 111145.945 | 16548.109 |
| facade | 85054.207 | 17121.165 |
| facade repeat | 85446.437 | 16488.775 |
| baseline repeat | 107065.802 | 17650.273 |

Every sampled candidate and durable payload matched the baseline. Purchase mean
fell from about 109.1 s to 85.3 s (about 22%); draft time was essentially unchanged
(about 17 s). **These are still unacceptable interactive delays, not release-ready
performance.** Further profiling and bounded optimization remain required. The
four samples are local observations, not a statistically robust speed guarantee.

The final failure/retry trial and separate cold-process reopen passed on the same
source. The failure trial retained the exact baseline-equivalent paid candidate,
blocked repeated action, preserved pre-purchase disk bytes, and published that
candidate on retry. Cold validation restored paid/drafted payloads and the
unchanged source fixture under the original owner111 codec and source identity.
