class_name SeasonGapCommit
extends RefCounted
## Saved immutable contact inputs and one selected launch. Validation uses this snapshot only.
# gdlint: disable=max-returns


static func make(data: Dictionary, contact: ContactResult, left: bool) -> Dictionary:
	var choice: Dictionary = SeasonGapLane.choose(data, contact, &"swing.contact", 3, left)
	choice.erase("candidates")
	choice["sector"] = choice.get("sector", "")
	return {
		"version": 1,
		"snapshot": encode(data),
		"quality": contact.quality,
		"outcome": int(contact.outcome),
		"left": left,
		"original": contact.spray_degrees,
		"before_velocity": _array(contact.exit_velocity),
		"spin":
		[-contact.backspin_rad_s, -contact.spray_degrees * 0.62, contact.horizontal_error_m * 38.0],
		"choice": choice
	}


static func apply(contact: ContactResult, evidence: Dictionary) -> bool:
	if not contact.frozen_launch.is_empty():
		return same(contact.frozen_launch, evidence)
	if (
		not valid(evidence)
		or not same(evidence.quality, contact.quality)
		or evidence.outcome != int(contact.outcome)
		or not same(evidence.original, contact.spray_degrees)
		or not same(evidence.before_velocity, _array(contact.exit_velocity))
		or not same(
			evidence.spin,
			[
				-contact.backspin_rad_s,
				-contact.spray_degrees * 0.62,
				contact.horizontal_error_m * 38.0
			]
		)
	):
		return false
	contact.exit_velocity = _vector(evidence.choice.velocity)
	contact.spray_degrees = evidence.choice.selected
	contact.frozen_launch = evidence.duplicate(true)
	return true


static func valid(value: Variant) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(
			value,
			[
				"version",
				"snapshot",
				"quality",
				"outcome",
				"left",
				"original",
				"before_velocity",
				"spin",
				"choice"
			]
		)
	):
		return false
	if (
		not SeasonOwnership._whole(value.version, 1, 1)
		or not value.left is bool
		or not _number(value.quality, 0, 1)
		or not SeasonOwnership._whole(value.outcome, 2, 3)
		or not _number(value.original, -90, 90)
		or not _numbers(value.before_velocity, 3)
		or not _numbers(value.spin, 3)
	):
		return false
	if absf(value.spin[1] + value.original * 0.62) > 0.000001:
		return false
	var data: Dictionary = decode(value.snapshot)
	if data.is_empty():
		return false
	var contact: ContactResult = ContactResult.new()
	contact.quality = value.quality
	contact.outcome = int(value.outcome)
	contact.spray_degrees = value.original
	contact.exit_velocity = _vector(value.before_velocity)
	if contact.exit_velocity.length() <= 0.0 or contact.exit_velocity.length() > 1000.0:
		return false
	if (
		absf(rad_to_deg(atan2(contact.exit_velocity.x, contact.exit_velocity.z)) - value.original)
		> 0.0001
	):
		return false
	var expected: Dictionary = SeasonGapLane.choose(data, contact, &"swing.contact", 3, value.left)
	expected.erase("candidates")
	expected["sector"] = expected.get("sector", "")
	return same(expected, value.choice)


static func encode(data: Dictionary) -> Dictionary:
	if not data.valid:
		return {"valid": false}
	var defenders: Array = []
	var obstacles: Array = []
	for point: Vector2 in data.defenders:
		defenders.append([point.x, point.y])
	for box: Rect2 in data.obstacles:
		obstacles.append([box.position.x, box.position.y, box.size.x, box.size.y])
	return {
		"valid": true,
		"origin": [data.origin.x, data.origin.y],
		"near": data.near,
		"far": data.far,
		"half": data.half,
		"defenders": defenders,
		"obstacles": obstacles
	}


static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("valid") is bool:
		return {}
	if not value.valid:
		return {"valid": false} if SeasonOwnership._keys(value, ["valid"]) else {}
	if not SeasonOwnership._keys(
		value, ["valid", "origin", "near", "far", "half", "defenders", "obstacles"]
	):
		return {}
	if (
		not _numbers(value.origin, 2)
		or not _number(value.near, 0.0001, 10000)
		or not _number(value.far, value.near + 0.0001, 10000)
		or value.origin[1] >= value.near
		or not _number(value.half, 0.0001, 89.9999)
		or not value.defenders is Array
		or value.defenders.is_empty()
		or value.defenders.size() > 16
		or not value.obstacles is Array
		or value.obstacles.size() > 128
	):
		return {}
	var defenders: Array[Vector2] = []
	var obstacles: Array[Rect2] = []
	for point: Variant in value.defenders:
		if not _numbers(point, 2):
			return {}
		defenders.append(Vector2(point[0], point[1]))
	for box: Variant in value.obstacles:
		if not _numbers(box, 4) or box[2] <= 0 or box[3] <= 0:
			return {}
		obstacles.append(Rect2(box[0], box[1], box[2], box[3]))
	return {
		"valid": true,
		"origin": Vector2(value.origin[0], value.origin[1]),
		"near": value.near,
		"far": value.far,
		"half": value.half,
		"defenders": defenders,
		"obstacles": obstacles
	}


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if not command.has("frozen"):
		return ""
	var rows: Variant = command.frozen
	var receipt: Dictionary = SeasonMatchInventory.gear(build).get("bat", {})
	if (
		build._format < 41
		or not rows is Array
		or rows.is_empty()
		or rows.size() > 9999
		or receipt.get("item", "") != SeasonFrozenRope.ID
		or not command.get("used_gear", []).has(receipt.get("id", ""))
	):
		return "Frozen Rope contact evidence requires its actual completed-game paid copy."
	if (
		command.has("stances")
		and not SeasonLeftRight.valid(build, command.stances, command.get("performance", {}))
	):
		return "Frozen Rope requires valid committed batting-side evidence."
	var previous: Dictionary = {}
	for row: Variant in rows:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(row, ["pitch", "pa", "half", "player", "launch"])
			or not SeasonOwnership._whole(row.pitch, 1, 9999999)
			or not SeasonOwnership._whole(row.pa, 1, 99999)
			or not SeasonOwnership._whole(row.half, 0, 9999)
			or not row.player is String
			or not build.roster().has(row.player)
			or command.get("performance", {}).get(row.player, {}).get("pa", 0) < 1
			or not valid(row.launch)
		):
			return "Invalid committed Frozen Rope launch."
		if (
			not previous.is_empty()
			and (row.pitch <= previous.pitch or row.pa < previous.pa or row.half < previous.half)
		):
			return "Frozen Rope contacts must remain in committed pitch order."
		var player: PlayerDefinition = build.definition(row.player)
		if (
			not player.switch_hitter
			and row.launch.left != (player.bats == PlayerDefinition.Handedness.LEFT)
		):
			return "Frozen Rope must use the committed batting side."
		if not command.get("stances", []).is_empty():
			var stances: Array = command.stances.filter(
				func(side: Dictionary) -> bool:
					return side.pa == row.pa and side.half == row.half and side.player == row.player
			)
			if stances.size() != 1 or stances[0].left != row.launch.left:
				return "Frozen Rope launch differs from its committed plate appearance."
		previous = row
	return ""


static func same(first: Variant, second: Variant) -> bool:
	if first is Dictionary:
		if not second is Dictionary or first.size() != second.size():
			return false
		for key: Variant in first:
			if not second.has(key) or not same(first[key], second[key]):
				return false
		return true
	if first is Array:
		if not second is Array or first.size() != second.size():
			return false
		for index in range(first.size()):
			if not same(first[index], second[index]):
				return false
		return true
	if first is float or first is int:
		return (
			(second is float or second is int)
			and is_finite(float(second))
			and absf(first - second) <= 0.000001
		)
	return first == second


static func _number(value: Variant, low: float, high: float) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= low
		and value <= high
	)


static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number: Variant in value:
		if not _number(number, -10000, 10000):
			return false
	return true


static func _array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
