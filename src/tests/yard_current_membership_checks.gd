extends RefCounted
## Test-only exact-current registry controls. Never installs a property or changes authority.
## Expected canonical bytes are frozen fixtures, not values derived from the lookup under test.

const FIXTURES: Dictionary = {
	"AY-02":
	{
		"path": "res://src/tests/fixtures/npc_yard_two_r1_candidate_canonical.json",
		"sha256": "fb15cd5c23ab70e3498e0888aea409e9f03b4dedbac59e8c507fc70014327041",
		"instances": 4
	},
	"AY-03":
	{
		"path": "res://src/tests/fixtures/npc_yard_three_r1_candidate_canonical.json",
		"sha256": "4ce7a2b451994bd64a0173c80bb30dc001f4229b6f6d1e5383b253012415e652",
		"instances": 8
	}
}


static func check(id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not _control(rows, FIXTURES.has(id), "helper accepts only the two reviewed exact venue IDs"):
		return rows
	var fixture: Dictionary = FIXTURES[id]
	var bytes: String = FileAccess.get_file_as_string(fixture.path)
	if not _control(
		rows,
		(
			FileAccess.get_sha256(fixture.path) == fixture.sha256
			and bytes.sha256_text() == fixture.sha256
		),
		"retained canonical fixture has its independently fixed byte hash"
	):
		return rows
	var value: Dictionary = StadiumNpcVenues.definition(id, 1)
	if not _control(rows, not value.is_empty(), "exact current revision1 membership exists"):
		return rows
	_control(
		rows,
		_json(value) == bytes,
		"complete current revision1 bytes equal frozen canonical fixture"
	)
	_control(
		rows,
		(
			value.get("id") == id
			and value.get("revision") == 1
			and value.get("field") == "field.npc_venue"
			and value.get("instances") is Array
			and value.instances.size() == fixture.instances
		),
		"current membership has exact venue, revision, field and composition identity"
	)
	_control(
		rows,
		(
			StadiumNpcVenues.valid_manifest(value)
			and StadiumNpcVenues.key(value) == fixture.sha256
			and _json(StadiumNpcVenues.decode(bytes)) == bytes
		),
		"exact canonical member validates, hashes and decodes through the public registry"
	)
	var expected_availability: Dictionary = {
		"id": id,
		"revision": 1,
		"data_admitted": true,
		"production_runtime": true,
		"selectable": true
	}
	_control(
		rows,
		StadiumNpcAvailability.record(id, 1) == expected_availability,
		"exact current availability declaration has only the reviewed revision1 fields"
	)
	_control(
		rows,
		(
			StadiumNpcVenues.definition(id, 2).is_empty()
			and StadiumNpcAvailability.record(id, 2).is_empty()
		),
		"revision2 is absent from both independent lookup surfaces"
	)
	for revision: int in [-1, 0, 3, 2147483647]:
		_control(
			rows,
			(
				StadiumNpcVenues.definition(id, revision).is_empty()
				and StadiumNpcAvailability.record(id, revision).is_empty()
			),
			"invalid or future revision remains closed: " + str(revision)
		)
	for unknown: String in ["", "AY-00", "AY-04", id.to_lower(), id + " "]:
		for revision: int in [1, 2]:
			_control(
				rows,
				(
					StadiumNpcVenues.definition(unknown, revision).is_empty()
					and StadiumNpcAvailability.record(unknown, revision).is_empty()
				),
				(
					"unknown venue or alias remains closed: "
					+ JSON.stringify(unknown)
					+ "/"
					+ str(revision)
				)
			)
	for mutation: String in ["future-revision", "unknown-id", "authority-flag"]:
		var forged: Dictionary = value.duplicate(true)
		match mutation:
			"future-revision":
				forged.revision = 2
			"unknown-id":
				forged.id = "AY-04"
			"authority-flag":
				forged["data_admitted"] = true
		_control(
			rows,
			(
				not StadiumNpcVenues.valid_manifest(forged)
				and StadiumNpcVenues.key(forged).is_empty()
				and StadiumNpcVenues.decode(_json(forged)).is_empty()
			),
			"caller-edited or self-declared authority cannot publish a manifest: " + mutation
		)
	if _control(
		rows,
		(
			value.get("instances") is Array
			and not value.instances.is_empty()
			and value.instances[0] is Dictionary
			and value.instances[0].get("transform") is Array
			and value.instances[0].transform.size() == 12
		),
		"independent nested mutation control has a full transform"
	):
		var changed: Dictionary = value.duplicate(true)
		changed.instances[0].transform[9] = float(changed.instances[0].transform[9]) + 0.001
		_control(
			rows,
			(
				_json(changed) != bytes
				and not StadiumNpcVenues.valid_manifest(changed)
				and StadiumNpcVenues.decode(_json(changed)).is_empty()
			),
			"well-formed geometry mutation cannot inherit exact registry membership"
		)
		value.instances[0].transform[9] = float(value.instances[0].transform[9]) + 0.001
		_control(
			rows,
			_json(value) != bytes and _json(StadiumNpcVenues.definition(id, 1)) == bytes,
			"mutating returned nested definition cannot alter the immutable registered member"
		)
	var detached: Dictionary = StadiumNpcAvailability.record(id, 1)
	detached.clear()
	_control(
		rows,
		detached.is_empty() and StadiumNpcAvailability.record(id, 1) == expected_availability,
		"mutating returned availability cannot revoke or rewrite registry data"
	)
	return rows


static func _control(rows: Array[Dictionary], ok: bool, label: String) -> bool:
	rows.append({"ok": ok, "label": label})
	return ok


static func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)
