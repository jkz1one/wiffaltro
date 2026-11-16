extends RefCounted
## Presentation strings only. Signed catalog data and gameplay mappings stay unchanged.

const MAPPING_NOTES: Dictionary = {
	"A04": " Proposed control-range mapping.",
	"MISC-FLD-01": " Proposed deterministic error mapping; no extra random roll.",
	"MISC-FLD-02": " Proposed deterministic error mapping; reach/height limits still apply."
}


static func effect(id: String, item: Dictionary, fallback: String = "") -> String:
	var text: String = str(item.get("effect", fallback))
	return text.trim_suffix(MAPPING_NOTES[id]) if MAPPING_NOTES.has(id) else text


static func status(
	id: String, item: Dictionary, prefix: String = "", suffix: String = ""
) -> String:
	var text: String = str(item.get("status", "Working"))
	if (
		text == "Working"
		or (MAPPING_NOTES.has(id) and text == "Proposal — unapproved engine mapping")
		or (id in ["A02", "BAT-ALY-02"] and text == "Working calibration")
	):
		return ""
	return "" if text.is_empty() else prefix + text + suffix
