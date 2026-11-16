extends RefCounted
## Closed-playtest display only. Original errors remain in controllers/store state.
## Exact aliases avoid rewriting unknown diagnostics or implying a successful save.

const PENDING: String = ("A saved action still needs to finish. Recover your save before " + \
	"continuing; it cannot be canceled or replaced here.")
const RECOVERY: String = ("Your save needs recovery before you can continue. Recovery keeps the " \
	+ "saved team and season.")
const BLOCKED: String = ("This save cannot be opened safely. Recovery cannot substitute a new " + \
	"team or an older season.")
const UNCERTAIN: String = ("The action could not be confirmed. Retry the same action or recover " \
	+ "your save. Do not start a replacement.")

const NOTICES: Dictionary = {
	"Open a saved closed owner at a safe hub first.":
	"Open your saved playtest Dynasty and return to the clubhouse before starting setup.",
	"This setup only creates the owner's first non-Dynasty alternate.":
	"Choose a league for your first alternate. Dynasty can't be created here.",
	"Recover the saved owner before preparing a new alternate.":
	"Recover your save before setting up an alternate.",
	"The live source differs from its saved checkpoint. Save or recover it first.":
	"Your current season differs from its save. Save or recover it before continuing.",
	"The requested closed season could not be prepared.": "Couldn't prepare this playtest season.",
	"The fresh inventory contract could not be admitted; your setup is unchanged.":
	"Couldn't finish setting up this season. Your draft is unchanged.",
	"The prepared roster failed validation; your setup is unchanged.":
	"Couldn't prepare this roster. Your draft is unchanged.",
	"The saved owner binding changed. Reopen setup.": "The active save changed. Reopen setup.",
	"The saved owner changed or needs recovery. This setup cannot replace it.":
	"Your save changed or needs recovery. This draft can't overwrite it.",
	"The live source changed. Save or recover it before continuing.":
	"Your current season changed. Save or recover it before continuing.",
	"This enrollment choice is out of date.": "This start choice is out of date. Reopen setup.",
	"Return to the original saved owner at a safe hub first.":
	"Return to this setup's saved season at the clubhouse before continuing.",
	"Choose all four players before enrolling.":
	"Choose all four players before starting the season.",
	"The completed setup could not be validated.": "Couldn't finish preparing this roster.",
	"Enrollment needs its exact retry or recovery.":
	"Couldn't confirm the start. Retry with this roster or recover your save.",
	"Return to the saved owner at a safe hub before recovery.":
	"Return to the clubhouse for this saved season before recovery.",
	"Use the closed catalog to prepare your first alternate.":
	"Open Playtest Leagues to set up your first alternate.",
	"Recover the saved owner before switching.": "Recover your save before switching leagues.",
	"An enrollment may already be committed or pending. Retry or recover it; do not reset it.":
	"The season may already be saved. This setup can't be canceled now. Retry or recover it.",
	"The saved owner needs recovery.": "Your save needs recovery.",
	"Initial owner proposal awaits its exact request retry.": PENDING,
	"Uncommitted owner intent locks its exact request and target.": PENDING,
	"Pending owner intent permits only its exact admitted request.": PENDING,
	"Joint owner commit is proven; exact repair remains.": RECOVERY,
	"One owner manifest replica is unavailable.": RECOVERY,
	"Repair committed owner redundancy before requesting a new transition.": RECOVERY,
	"The exact selected snapshot is unavailable; no older snapshot or .bak fallback is permitted.":
	BLOCKED,
	"Selected snapshot failed full source qualification against its owner manifest.": BLOCKED,
	"Invalid owner intent; manifest and object evidence preserved.": BLOCKED,
	"Owner replicas conflict with the exact pending transition.": BLOCKED,
	"Source-only mirror and unavailable primary are ambiguous; no rollback selected.": BLOCKED,
	"Different valid owner replicas lack a validating intent.": BLOCKED,
	"Invalid or legacy owner evidence cannot initialize a replacement.": BLOCKED,
	"An exact required snapshot is unavailable; inactive references were preserved.": BLOCKED,
	"Pending source failed exact owner qualification; all evidence is preserved.": BLOCKED,
	"Pending selected target is unavailable; all evidence is preserved.": BLOCKED,
	"Pending checkpoint failed exact source extension; all evidence is preserved.": BLOCKED,
	"Pending selected target failed full qualification; all evidence is preserved.": BLOCKED,
	"Neither exact same-digest snapshot copy is available.": BLOCKED,
	"Neither exact selected-snapshot replica can supply recovery.": BLOCKED,
	"Owner intent could not be revalidated; no owner may be promoted.": UNCERTAIN,
	"Interrupted while preparing the joint owner intent.": UNCERTAIN,
	"Interrupted while preparing the joint owner intent. No live owner may be promoted.": UNCERTAIN,
	"Interrupted at the joint owner commit boundary.": UNCERTAIN,
	"Interrupted at the joint owner commit boundary. No live owner may be promoted.": UNCERTAIN,
}


static func notice(message: String) -> String:
	return str(NOTICES.get(message, message))


static func recovery(status: String, content_blocked: bool = false) -> String:
	if content_blocked:
		return BLOCKED
	match status:
		"pending":
			return PENDING
		"recoverable", "ready":
			return RECOVERY
	return BLOCKED
