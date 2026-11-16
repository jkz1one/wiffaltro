# Separate closed Dugout admission — 2026-11-16

This is inactive integration groundwork, not a playable League. It preserves
all historical source and the existing successor-v7 domain byte-for-byte.
A separate 37-script namespace carries an independently hashed contract and save
slot; factory/fork/replay paths remain in that namespace instead of silently
constructing historical or standalone builds. Twenty-eight scripts are mechanical
namespace copies; nine contain the documented admission/format/rule changes.
The frozen authored pitch provider and style materializer remain shared, with
pitch content version 7 unchanged.

The new domain uses outer/admission108, Build108 wrapping base45 and Development8
wrapping base1. Its format is `successor-dugout-v7-r1`. Only normalized Dugout tier0,
closed/non-live draft or freshly drafted state is accepted. Career, inventory,
access, grants, Dynasty, venues, inherited Exotic history, completed results,
pending physical reports and reward/shop journals are not admitted here. This is
a deliberate temporary integration boundary, not removal of those planned features.

The historical passive snapshot helper emits a League75 shell. The new codec
validates its exact keys/version/rules and extracts the inner Season57 payload;
it does not use the historical League decoder. New-domain replay and exact
recapture remain required. No v7 migration, re-signing or deletion occurs.

## Reproducible native checks

`python tools/test_successor_signature.py --dugout` uses a fresh isolated project
and user-data directory, then a separate cold Godot 4.6.3 process. It checks:

- Separate standalone-v7 and closed Dugout slots.
- Zero-pick capture/restore, then all four real draft choices. Each next choice
  continues from the previous JSON-restored checkpoint, not the original in-memory run.
- Dugout rules and three held/five sponsor slots in the player and all five AI
  builds, including exact new-domain identities and AI market12.
- Rejection of unsupported live admission, another League/tier, changed envelope
  version/format/catalog, changed rule fields or seed, and unexpected contexts.
- Mutual rejection of standalone and Dugout envelopes.
- A pending fixture exists, but the existing non-live guard refuses gameplay.
- Durable save, exact separate-process recapture and retained draft/capacities.
- Standalone slot bytes, signature and readability remain unchanged.
- Completed-result data cannot be captured under this admission-only envelope.

The first full test expected match construction and failed at that assertion.
Inspection confirmed the intentionally preserved non-live gameplay guard; the
corrected test requires rejection and tests saving separately. That exposed a
real JSON-only replay failure: raw JSON rules contain integral floats, while
strict runtime identity checks require canonical rules. The codec now passes
`LeagueRules.normalized` output to its decoder only after exact envelope/rule
validation. No decoder, scope or recapture validator was relaxed. Every draft
checkpoint now traverses JSON before resume. No game behavior was bypassed.

## Still required

Explicit live League admission and actual round/shop settlement; the remaining
League rules and tiers; career unlock/completion binding; Dynasty carry/decay,
replacement and resume; visual/input playtesting and distributable export.
A closed Dugout draft test is not proof of any of those. Raw logs and isolated
saves remain outside source. Future edits change this new experimental domain's
signature; its isolated evidence is retained, not silently reinterpreted. The
existing standalone-v7 reader and source are unchanged.
