class_name StadiumNpcAvailability
extends RefCounted
## Exact data availability only. Does not participate in manifest identity or selection.


static func record(id: String, revision: int) -> Dictionary:
	var records: Dictionary = {
		"AY-02": {"1": {"id": "AY-02", "revision": 1, "data_admitted": true,
			"production_runtime": true, "selectable": true}},
		# Daylight candidate route only; qualification requires the focused native tests.
		"AY-03": {"1": {"id": "AY-03", "revision": 1, "data_admitted": true,
			"production_runtime": true, "selectable": true}},
		"AY-01":
		{
			"1":
			{
				"id": "AY-01",
				"revision": 1,
				"data_admitted": true,
				"production_runtime": false,
				"selectable": false
			},
			"2":
			{
				"id": "AY-01",
				"revision": 2,
				"data_admitted": true,
				"production_runtime": true,
				"selectable": true
			}
		},
		"AE-01":
		{
			"1":
			{
				"id": "AE-01",
				"revision": 1,
				"data_admitted": true,
				"production_runtime": false,
				"selectable": false
			},
			"2":
			{
				"id": "AE-01",
				"revision": 2,
				"data_admitted": true,
				"production_runtime": true,
				"selectable": true
			}
		},
		"AC-01":
		{
			"1":
			{
				"id": "AC-01",
				"revision": 1,
				"data_admitted": true,
				"production_runtime": false,
				"selectable": false
			},
			"2":
			{
				"id": "AC-01",
				"revision": 2,
				"data_admitted": true,
				"production_runtime": true,
				"selectable": true
			}
		},
	}
	if not records.has(id) or not records[id].has(str(revision)):
		return {}
	return records[id][str(revision)].duplicate(true)
