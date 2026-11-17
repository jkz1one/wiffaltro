# General save validation cost diagnostic

No engine optimization is introduced by this increment. It adds an isolated
measurement harness and preserves full validation. Its input is an actual earned
Standard one-round/paid-pack Game114 checkpoint produced on checkpoint31 source.
The diagnostic copies that input into its own save slot; it does not replay the
original purchase, fabricate another transaction, or modify the source fixture.

## Verified scope

Godot 4.6.3 passes strict source restoration, input/file/held-authored-Resource
invariance, separate baseline validation boundaries, an actual unchanged-state
public save, exact canonical primary and original backup bytes, absent temporary
file, and separate fresh-process public reopen. The new test files do not change
the bound game catalog or original engine source.

The candidate deliberately equals the source state. This is not a normal shop
click measurement. Samples are sequential, warm with held Resources except the
explicit fresh-process reopen. There is one sample per boundary, other tests were
running, and measured durations overlap internally. They must not be summed as a
transaction total or presented as a hardware-independent speed prediction.

## Observed seconds in the qualifying run

| Boundary | Seconds |
| --- | ---: |
| Old-state clone capture | 0.768444 |
| Old-state clone restore | 15.000965 |
| Unchanged candidate capture | 0.717373 |
| Candidate full-precision serialize plus parse | 0.029980 |
| Candidate restore including its internal recapture | 14.542963 |
| Save's immediate extra candidate recapture | 0.522265 |
| Old-disk read plus parse | 0.007316 |
| Old-disk backup-eligibility restore | 13.184055 |
| Prewrite candidate recapture | 0.478558 |
| Actual unchanged-state public Save.save total | 27.271198 |
| Postsave primary and backup readback only | 0.000237 |
| Fresh-process Save.restore, excluding engine startup | 13.465708 |

The separate initial source-qualification restore took 15.229998 seconds. It is
harness setup, not an additional production save stage.

## Interpretation and next boundary

Validation replay dominates this fixture, not serialization or disk readback.
A normal App transaction separately restores the old state to clone it, validates
the changed candidate, and restores the old disk save to determine backup
eligibility. These are not three identical candidate restores. Terminal112's
resource-holding facade does not remove them.

Codec.restore already recaptures and compares the candidate. The immediate
additional capture in Save is redundant under that exact contract, but its
measured half-second cost cannot plausibly solve the larger responsiveness issue.
No removal or speedup is claimed here.

A larger bounded proposal is a private synchronous transaction that itself owns
old-state capture/restore, a fixed supported mutation, candidate validation and
publication. Its own old-state proof may cover backup eligibility only when the
actual old disk JSON equals that validated input. Otherwise full old-disk restore
remains necessary. Never substitute the pre-mutation proof for changed-candidate
validation, accept a caller-supplied trust flag, retain proof through retry, or
skip full cold restoration. This remains a proposal, not implemented behavior.
