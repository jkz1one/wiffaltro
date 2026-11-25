"""Create a distinct catalogue identity in the disposable laboratory copy only."""
from hashlib import sha256
from pathlib import Path


INPUTS = {
    "src/gameplay/pitching/working_pitch_catalog_v6.gd":
        "0e709f6bda6fa95a8fa7cc666ad31354cc223633c8c0782254adeb8d16820dff",
    "src/gameplay/season/successor_league_general_v2/catalog_context.gd":
        "d33a97f61a4dc4de5fec3495b40c419de34b1e7dae46d6ee55746a1a8311cfbb",
}


def once(text, before, after):
    if text.count(before) != 1:
        raise ValueError("The pinned source shape changed")
    return text.replace(before, after)


def signatures(text):
    return once(text, "static func signature() -> String:\n", """static var _forward_probe_signature: String = ""

static func signature() -> String:
	if _forward_probe_signature.is_empty():
		_forward_probe_signature = _fresh_probe_signature()
	return _forward_probe_signature

static func _fresh_probe_signature() -> String:
""")


def recipes(text):
    text = once(text, "static func recipes() -> Array[PitchDefinition]:\n", """static var _probe_templates: Array[PitchDefinition] = []

static func _catalog_templates() -> Array[PitchDefinition]:
	if _probe_templates.is_empty():
		_probe_templates = _read_templates()
	return _probe_templates

static func recipes() -> Array[PitchDefinition]:
	var result: Array[PitchDefinition] = []
	for pitch: PitchDefinition in _catalog_templates():
		result.append(detached_recipe(pitch))
	return result

static func _read_templates() -> Array[PitchDefinition]:
""")
    prefix, tail = text.split("static func _read_templates", 1)
    tail = once(tail, "\tfor pitch: PitchDefinition in recipes():\n\t\tresult.append(String(pitch.id))",
                "\tfor pitch: PitchDefinition in _catalog_templates():\n\t\tresult.append(String(pitch.id))")
    tail = once(tail, "\tfor pitch: PitchDefinition in recipes():\n\t\tif String(pitch.id) == id:\n\t\t\treturn pitch",
                "\tfor pitch: PitchDefinition in _catalog_templates():\n\t\tif String(pitch.id) == id:\n\t\t\treturn detached_recipe(pitch)")
    return prefix + "static func _read_templates" + tail


def apply(project: Path):
    original = {}
    project = project.resolve()
    if project.name != "shadow" or not (project / "forward_catalog_qa/round.gd").is_file():
        raise ValueError("This diagnostic may only change the separate shadow laboratory project")
    for name, expected in INPUTS.items():
        path = project / name
        if path.is_symlink() or not path.is_file():
            raise ValueError("Not a regular assembled source")
        data = path.read_bytes()
        if sha256(data).hexdigest() != expected:
            raise ValueError("The laboratory input has changed")
        original[path] = data.decode()
    for path, transform in zip(original, (recipes, signatures), strict=True):
        path.write_text(transform(original[path]))
