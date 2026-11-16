# Source checkpoint protocol

This development branch preserves source increments independently of a local workspace. It is not a release or a claim that gameplay tests pass.

## Starting point

The recoverable baseline is commit `bf1dd2e42d1ff122511cd734a1cffb22466b1e0a`. Its `drafts/successor-v7/DRAFT_MANIFEST.json` records 47 inactive draft files and their restore paths, byte counts and SHA-256 hashes. The draft is not installed in the default runtime. Preserve historical source and save compatibility.

## Gate for every increment

1. Read the current remote head and audit an explicit file allowlist. Publish source, tests and non-sensitive technical documentation only. Exclude saves, personal fixtures, raw session evidence, credentials and workspace archives.
2. Test the exact increment locally using isolated saves. Record accurately what passed, failed or was not run. Keep untested draft source clearly labeled.
3. Create a tree and commit based on the observed head. Advance this branch only with `expected_sha` equal to that head and `force=false`. On a mismatch, inspect and reconcile; never overwrite another writer.
4. Independently read the remote ref and changed files at the resulting commit. Compare exact bytes or hashes. A returned write success alone is not a verified checkpoint.
5. Do not begin the next substantial implementation batch until that receipt is verified. Local copies and archives do not satisfy this gate.

Leave `main` unchanged. A denied publication must be resolved for that concrete action, not retried through another route. No historical local test claim substitutes for tests against the current source.
